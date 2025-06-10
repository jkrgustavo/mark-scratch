require "plenary.busted"
local ui_module = require "mark-scratch.ui"
local config = require "mark-scratch.config"

local eq = assert.are.same

describe("Mark-scratch ui", function()
    local ui  -- This will be our ui instance

    before_each(function()
        require('plenary.reload').reload_module('mark-scratch.ui')
        require('plenary.reload').reload_module('mark-scratch.config')
        ui_module = require("mark-scratch.ui")
        config = require("mark-scratch.config")

        -- Create a new ui instance with the default config
        ui = ui_module.new(config.default_config.window)
        ui:setup({})
    end)

    after_each(function()
        if ui then
            ui:shutdown()
        end
    end)

    it("Setup correctly initializes ui", function()
        eq(ui:validate(), true, "validate failed")
        eq(ui.initialized, true)
        eq(
            config.default_config.window,
            ui.config,
            "ui config doesn't match the default")
    end)

    it("Autocommands work as expected", function()
        ui:open_window()
        vim.api.nvim_exec_autocmds('BufLeave', { buffer = ui.bufnr })
        vim.schedule(function()
            eq(ui.windnr, nil, "bufleave didn't close the window")
        end)

        ui:open_window()
        vim.api.nvim_exec_autocmds('WinClosed', { buffer = ui.bufnr })
        vim.schedule(function()
            eq(ui.windnr, nil, "winclosed didn't close the window")
        end)
    end)

    it("Usercommands work correctly", function()
        local lines = {
            "# A title",
            "",
            "Some text"
        }
        local getlines = function()
            return vim.api.nvim_buf_get_lines(ui.bufnr, 0, -1, false)
        end

        eq(getlines(), { '' }, "buffer has contents before anything was added")
        ui:set_contents(lines)

        vim.cmd("MSOpen")
        eq(ui.windnr and true, true, "windnr was falsy")
        eq(vim.api.nvim_win_is_valid(ui.windnr), true, "invalid window")

        local wnr = ui.windnr or -1
        vim.cmd("MSClose")
        vim.schedule(function()
            eq(ui.windnr, nil, "close didn't set windnr to nil")
            eq(vim.api.nvim_win_is_valid(wnr), false, "close didn't close window")
        end)

        eq(getlines(), lines, "lines changed when they shouldn't've")
        vim.cmd("MSClear")
        eq(getlines(), { '' }, "clear didn't clear the buffer")
    end)

    it("Shutdown deinitializes everyting", function()
        eq(ui:validate(), true)

        local wnr = ui.windnr or -1
        local bnr = ui.bufnr or -1
        ui:shutdown()

        eq(ui:validate(), false)
        eq(ui.windnr, nil)
        eq(ui.bufnr, -1)
        eq(vim.api.nvim_win_is_valid(wnr), false)
        eq(vim.api.nvim_buf_is_valid(bnr), false)
    end)
end)
