require "plenary.busted"
local Utils = require "mark-scratch.tests.utils"
local msp = require "mark-scratch.lsp"
local logger = require "mark-scratch.logger"

local eq = assert.are.same

describe("Mark-scratch LSP", function()
    local lsp_instance
    local test_bufnr

    before_each(function()
        require('plenary.reload').reload_module('mark-scratch.lsp')
        require('plenary.reload').reload_module('mark-scratch.logger')
        msp = require("mark-scratch.lsp")
        logger.logg:clear()

        -- Create a test buffer
        test_bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value('filetype', 'scratchmarkdown', { buf = test_bufnr})
    end)

    after_each(function()
        -- Clean up LSP if started
        if lsp_instance and lsp_instance.started then
            lsp_instance:stop_lsp(test_bufnr)
            -- Wait for cleanup
            Utils.wait_until(function()
                return not lsp_instance.started
            end)
        end

        -- Clean up buffer
        if vim.api.nvim_buf_is_valid(test_bufnr) then
            vim.api.nvim_buf_delete(test_bufnr, { force = true })
        end

        logger.logg:clear()
    end)

    it("creates new msp instance correctly", function()
        lsp_instance = msp.new()

        eq(lsp_instance.started, false)
        eq(lsp_instance.client, nil)
        eq(type(lsp_instance.start_lsp), "function")
        eq(type(lsp_instance.stop_lsp), "function")
    end)

    it("validates correctly when not started", function()
        lsp_instance = msp.new()

        -- Should be invalid when checking for started state
        eq(lsp_instance:validate(test_bufnr, { started = true }), false)

        -- Should be valid when checking for stopped state
        eq(lsp_instance:validate(test_bufnr, { stopped = true }), true)
    end)

    it("starts and stops LSP", function()
        lsp_instance = msp.new()

        -- Check if marksman is available
        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        lsp_instance:start_lsp(test_bufnr)

        -- Wait for LSP to be attached
        local attached = Utils.wait_until(function()
            return lsp_instance.started and
                   lsp_instance.client ~= nil and
                   vim.lsp.buf_is_attached(test_bufnr, lsp_instance.client.id)
        end)

        eq(attached, true, "LSP failed to attach")
        eq(lsp_instance:validate(test_bufnr, { started = true }), true)

        -- Stop LSP
        local stopped = lsp_instance:stop_lsp(test_bufnr)
        eq(stopped, true)
        eq(lsp_instance.started, false)

        -- Wait for complete cleanup
        local cleaned_up = Utils.wait_until(function()
            local clients = vim.lsp.get_clients({ bufnr = test_bufnr })
            for _, client in ipairs(clients) do
                if not client._is_stopping then
                    return false
                end
            end
            return true
        end)

        eq(cleaned_up, true, "LSP cleanup failed")
        eq(lsp_instance:validate(test_bufnr, { stopped = true }), true)
    end)

    it("handles invalid buffer", function()
        lsp_instance = msp.new()
        local invalid_bufnr = 99999

        -- Should not crash when trying to start with invalid buffer
        local ok = pcall(function()
            lsp_instance:start_lsp(invalid_bufnr)
        end)
        eq(ok, false) -- Should error
    end)

    it("get_client returns client when started", function()
        lsp_instance = msp.new()

        -- Before starting, should return nil
        eq(lsp_instance:get_client(), nil)

        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        lsp_instance:start_lsp(test_bufnr)

        -- Wait for client to be ready
        local ready = Utils.wait_until(function()
            local client = lsp_instance:get_client()
            return client ~= nil and not client._is_stopping
        end)

        eq(ready, true, "Client never became ready")

        -- Should return valid client
        local client = lsp_instance:get_client()
        eq(client ~= nil, true)
        eq(type(client), "table")
        eq(client.name, "scratch-marksman")
    end)

    it("doesn't start multiple times", function()
        lsp_instance = msp.new()

        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        lsp_instance:start_lsp(test_bufnr)

        -- Wait for first start
        Utils.wait_until(function()
            return lsp_instance.started and lsp_instance.client ~= nil
        end)

        local first_client = lsp_instance:get_client()
        local first_client_id = first_client.id

        -- Clear logs before second attempt
        logger.logg:clear()

        -- Try to start again
        lsp_instance:start_lsp(test_bufnr)

        -- Should still be the same client
        eq(lsp_instance:get_client().id, first_client_id)

        -- Logger should not have "Lsp started" message for second call
        local log_lines = logger.logg:get_lines()
        local started_count = 0
        for _, line in ipairs(log_lines) do
            if line:match("Lsp started") then
                started_count = started_count + 1
            end
        end
        eq(started_count, 0, "LSP started multiple times")
    end)

    it("stops all attached clients", function()
        lsp_instance = msp.new()

        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        lsp_instance:start_lsp(test_bufnr)

        -- Wait for attachment
        Utils.wait_until(function()
            return #vim.lsp.get_clients({ bufnr = test_bufnr }) > 0
        end)

        -- Check that client is attached
        local attached_before = vim.lsp.get_clients({ bufnr = test_bufnr })
        eq(#attached_before > 0, true)

        -- Stop LSP
        local stop_result = lsp_instance:stop_lsp(test_bufnr)
        eq(stop_result, true, "stop_lsp returned false")

        -- Wait for all clients to stop
        local all_stopped = Utils.wait_until(function()
            local clients = vim.lsp.get_clients({ bufnr = test_bufnr })
            if #clients == 0 then return true end

            for _, client in ipairs(clients) do
                if not client._is_stopping then
                    return false
                end
            end
            return true
        end)

        eq(all_stopped, true, "Not all clients stopped")
    end)

    it("uses custom config when provided", function()
        lsp_instance = msp.new()

        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        local custom_config = {
            name = "test-marksman",
            init_options = {
                test = true
            }
        }

        lsp_instance:start_lsp(test_bufnr, custom_config)

        -- Wait for client
        local started = Utils.wait_until(function()
            return lsp_instance.client ~= nil
        end)

        eq(started, true, "Client never started with custom config")

        local client = lsp_instance:get_client()
        eq(client.name, "test-marksman")

        -- Check that default config was merged
        ---@diagnostic disable-next-line: undefined-field
        eq(client.config.filetypes[1], "scratchmarkdown")
    end)
end)
