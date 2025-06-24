require "plenary.busted"
local ui = require "mark-scratch.ui"
local config = require "mark-scratch.config"
local Winstate = require "mark-scratch.winstate"

local eq = assert.are.same

describe("Mark-scratch UI window state integration", function()

    before_each(function()
        -- local reload = require('plenary.reload').reload_module
        require('plenary.reload').reload_module('mark-scratch.ui')
        require('plenary.reload').reload_module('mark-scratch.config')
        ui = require("mark-scratch.ui")
        config = require("mark-scratch.config")
        Winstate = require("mark-scratch.winstate")

        -- Create a new ui instance with the default config
        ui:setup({})
    end)

    after_each(function()
        ui:shutdown()
    end)

    describe("window state persistence", function()
        it("preserves window position after manual resize", function()
            ui:open_window()

            local new_config = {
                row = 15,
                col = 25,
                width = 100,
                height = 40,
                relative = 'editor'
            }

            -- Simulate manual window resize
            vim.api.nvim_win_set_config(ui.windnr, new_config)

            -- Close window
            ui:close_window()

            -- Check state was preserved
            eq(ui.state.row, 15)
            eq(ui.state.col, 25)
            eq(ui.state.width, 100)
            eq(ui.state.height, 40)

            -- Reopen and verify position
            ui:open_window()
            local actual_config = vim.api.nvim_win_get_config(ui.windnr)
            eq(actual_config.row, 15)
            eq(actual_config.col, 25)
            eq(actual_config.width, 100)
            eq(actual_config.height, 40)
        end)
    end)

    describe("window type configurations", function()
        it("handles float window configuration", function()
            -- Start with a blank slate to test configuration
            ui:shutdown()

            ui:setup({
                window = {
                    wintype = 'float',
                    width = 80,
                    height = 30,
                    float_x = 20,
                    float_y = 10,
                }
            })

            ui:open_window()


            local win_config = vim.api.nvim_win_get_config(ui.windnr)
            eq(win_config.relative, 'editor')
            eq(win_config.width, 80)
            eq(win_config.height, 30)

            eq(ui.state.wintype, 'float')
            eq(ui.state.height, 30)
            eq(ui.state.col, 20)
            eq(ui.state.row, 10)
            eq(ui.state.width, 80)
        end)

        it("handles vertical split configuration", function()
            -- Start with a blank slate to test configuration
            ui:shutdown()

            local test_config = {
                window = {
                    wintype = 'split',
                    vertical = true,
                    width = 50,
                }
            }

            ui:setup(test_config)

            eq(ui.state.wintype, 'vertical')
        end)
    end)

    describe("state access patterns", function()
        it("provides read access to all state properties", function()
            ui:open_window()

            -- All state properties should be accessible
            assert.not_nil(ui.state.row)
            assert.not_nil(ui.state.col)
            assert.not_nil(ui.state.width)
            assert.not_nil(ui.state.height)
            assert.not_nil(ui.state.wintype)

            -- Verify they match expected values
            eq(ui.state.wintype, 'float')
            eq(type(ui.state.row), 'number')
            eq(type(ui.state.col), 'number')
            eq(type(ui.state.width), 'number')
            eq(type(ui.state.height), 'number')
        end)

        it("prevents setting invalid state properties", function()
            ui:open_window()

            -- Should error when trying to set non-existent properties
            assert.has_error(function()
                ---@diagnostic disable-next-line: inject-field
                ui.state.invalid_property = 123
            end)

            -- Valid properties should work
            assert.no_error(function()
                ui.state.row = ui.state.row + 5
            end)
        end)
    end)

    describe("keybind state updates", function()
        it("updates position via keybinds", function()
            ui:open_window()

            local initial_row = ui.state.row
            local initial_col = ui.state.col

            -- Simulate keybind actions
            -- These would normally be triggered by the actual keybinds
            ui.state.row = ui.state.row - 5  -- float_up
            eq(ui.state.row, initial_row - 5)

            ui.state.row = ui.state.row + 5  -- float_down
            eq(ui.state.row, initial_row)

            ui.state.col = ui.state.col - 5  -- float_left
            eq(ui.state.col, initial_col - 5)

            ui.state.col = ui.state.col + 5  -- float_right
            eq(ui.state.col, initial_col)

            -- Verify window actually moved
            local win_config = vim.api.nvim_win_get_config(ui.windnr)
            eq(win_config.row, initial_row)
            eq(win_config.col, initial_col)
        end)
    end)

    describe("edge cases", function()
        it("handles rapid state updates", function()
            ui:open_window()

            -- Perform multiple rapid updates
            for _ = 1, 10 do
                ui.state.row = ui.state.row + 1
                ui.state.col = ui.state.col + 1
            end

            eq(ui.state.row, config.default_config.window.float_y + 10)
            eq(ui.state.col, config.default_config.window.float_x + 10)

            local win_config = vim.api.nvim_win_get_config(ui.windnr)
            eq(win_config.row, ui.state.row)
            eq(win_config.col, ui.state.col)
        end)

        it("handles state updates when window is closed", function()
            ui:open_window()
            ui:close_window()

            -- State updates should work even without window
            assert.no_error(function()
                ui.state.row = 50
                ui.state.col = 60
                ui.state.width = 90
                ui.state.height = 35
            end)

            -- Verify state was updated
            eq(ui.state.row, 50)
            eq(ui.state.col, 60)
            eq(ui.state.width, 90)
            eq(ui.state.height, 35)

            -- Open window with new state
            ui:open_window()
            local win_config = vim.api.nvim_win_get_config(ui.windnr)
            eq(win_config.row, 50)
            eq(win_config.col, 60)
            eq(win_config.width, 90)
            eq(win_config.height, 35)
        end)

        it("maintains state through multiple open/close cycles", function()
            local positions = {
                { row = 10, col = 20 },
                { row = 15, col = 25 },
                { row = 20, col = 30 },
            }

            for _, pos in ipairs(positions) do
                ui:open_window()
                ui.state.row = pos.row
                ui.state.col = pos.col
                ui:close_window()

                eq(ui.state.row, pos.row)
                eq(ui.state.col, pos.col)
            end

            -- Final open should use last position
            ui:open_window()
            local win_config = vim.api.nvim_win_get_config(ui.windnr)
            eq(win_config.row, positions[#positions].row)
            eq(win_config.col, positions[#positions].col)
        end)
    end)

    describe("winstate callback integration", function()
        it("triggers winstate callback on state changes", function()
            local callback_count = 0
            ---@type ms.winstate
            local last_callback_data = nil

            -- Set up callback to track calls
            Winstate.set_callback(function(data)
                callback_count = callback_count + 1
                last_callback_data = vim.deepcopy(data)
            end)

            -- Re-setup UI to use new callback
            ui:shutdown()
            ui:setup({})
            ui:open_window()

            local initial_count = callback_count

            -- Make state changes
            ui.state.row = 25
            eq(callback_count, initial_count + 1)
            eq(last_callback_data.row, 25)

            ui.state.col = 35
            eq(callback_count, initial_count + 2)
            eq(last_callback_data.col, 35)

            ui.state.width = 100
            eq(callback_count, initial_count + 3)
            eq(last_callback_data.width, 100)
        end)
    end)
end)
