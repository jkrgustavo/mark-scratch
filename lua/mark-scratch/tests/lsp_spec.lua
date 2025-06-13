require "plenary.busted"
local Utils = require "mark-scratch.tests.utils"
local msp = require "mark-scratch.lsp"
local logger = require "mark-scratch.logger"

local eq = assert.are.same

describe("Mark-scratch LSP", function()
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
        if msp and msp.started then
            msp:stop_lsp(test_bufnr)
            -- Wait for cleanup
            Utils.wait_until(function()
                return not msp.started
            end)
        end

        -- Clean up buffer
        if vim.api.nvim_buf_is_valid(test_bufnr) then
            vim.api.nvim_buf_delete(test_bufnr, { force = true })
        end

        logger.logg:clear()
    end)

    it("creates new msp instance correctly", function()
        eq(msp.started, false)
        eq(msp.client, nil)
        eq(type(msp.start_lsp), "function")
        eq(type(msp.stop_lsp), "function")
    end)

    it("validates correctly when not started", function()
        -- Should be invalid when checking for started state
        eq(msp:validate(test_bufnr, { started = true }), false)

        -- Should be valid when checking for stopped state
        eq(msp:validate(test_bufnr, { stopped = true }), true)
    end)

    it("starts and stops LSP", function()
        -- Check if marksman is available
        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        msp:start_lsp(test_bufnr)

        -- Wait for LSP to be attached
        local attached = Utils.wait_until(function()
            return msp.started and
                   msp.client ~= nil and
                   vim.lsp.buf_is_attached(test_bufnr, msp.client.id)
        end)

        eq(attached, true, "LSP failed to attach")
        eq(msp:validate(test_bufnr, { started = true }), true)

        -- Stop LSP
        local stopped = msp:stop_lsp(test_bufnr)
        eq(stopped, true)
        eq(msp.started, false)

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
        eq(msp:validate(test_bufnr, { stopped = true }), true)
    end)

    it("handles invalid buffer", function()
        local invalid_bufnr = 99999

        -- Should not crash when trying to start with invalid buffer
        local ok = pcall(function()
            msp:start_lsp(invalid_bufnr)
        end)
        eq(ok, false) -- Should error
    end)

    it("get_client returns client when started", function()

        -- Before starting, should return nil
        eq(msp.client, nil)

        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        msp:start_lsp(test_bufnr)

        -- Wait for client to be ready
        local ready = Utils.wait_until(function()
            local client = msp.client or error("nil client")
            return client ~= nil and not client._is_stopping
        end)

        eq(ready, true, "Client never became ready")

        -- Should return valid client
        local client = msp.client or error("nil client")
        eq(client ~= nil, true)
        eq(type(client), "table")
        eq(client.name, "scratch-marksman")
    end)

    it("doesn't start multiple times", function()

        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        msp:start_lsp(test_bufnr)

        -- Wait for first start
        Utils.wait_until(function()
            return msp.started and msp.client ~= nil
        end)

        local first_client = msp.client or error("nil client")
        local first_client_id = first_client.id

        -- Clear logs before second attempt
        logger.logg:clear()

        -- Try to start again
        msp:start_lsp(test_bufnr)

        -- Should still be the same client
        eq(msp.client.id, first_client_id)

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

        local has_marksman = vim.fn.executable('marksman') == 1
        if not has_marksman then
            pending("marksman not available")
            return
        end

        -- Start LSP
        msp:start_lsp(test_bufnr)

        -- Wait for attachment
        Utils.wait_until(function()
            return #vim.lsp.get_clients({ bufnr = test_bufnr }) > 0
        end)

        -- Check that client is attached
        local attached_before = vim.lsp.get_clients({ bufnr = test_bufnr })
        eq(#attached_before > 0, true)

        -- Stop LSP
        local stop_result = msp:stop_lsp(test_bufnr)
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

        msp:start_lsp(test_bufnr, custom_config)

        -- Wait for client
        local started = Utils.wait_until(function()
            return msp.client ~= nil
        end)

        eq(started, true, "Client never started with custom config")

        local client = msp.client or error("nil client")
        eq(client.name, "test-marksman")

        -- Check that default config was merged
        ---@diagnostic disable-next-line: undefined-field
        eq(client.config.filetypes[1], "scratchmarkdown")
    end)
end)
