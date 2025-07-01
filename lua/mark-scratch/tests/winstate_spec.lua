---@diagnostic disable: missing-fields
require "plenary.busted"
local Winstate = require "mark-scratch.winstate"
-- local Config = require "mark-scratch.config"

local eq = assert.are.same

describe("Mark-scratch winstate", function()

    before_each(function()
        local reload = require('plenary.reload').reload_module
        reload('mark-scratch.winstate')
        reload('mark-scratch.config')
        Winstate = require("mark-scratch.winstate")
        -- Config = require("mark-scratch.config")
    end)

    describe("msconfig_to_winstate conversions", function()
        it("converts float window config correctly", function()
            local config = {
                wintype = 'float',
                height = 20,
                width = 80,
                float_y = 10,
                float_x = 15,
                vertical = false,
            }

            local state = Winstate.msconfig_to_winstate(config)

            eq(state.wintype, 'float')
            eq(state.height, 20)
            eq(state.width, 80)
            eq(state.row, 10)
            eq(state.col, 15)
        end)

        it("converts vertical split config correctly", function()
            local config = {
                wintype = 'split',
                vertical = true,
                width = 40,
                height = 20, -- should be ignored for vertical
            }

            local state = Winstate.msconfig_to_winstate(config)

            eq(state.wintype, 'vertical')
            eq(state.width, 40)
            eq(state.height, nil)
        end)

        it("converts horizontal split config correctly", function()
            local config = {
                wintype = 'split',
                vertical = false,
                width = 80,
                height = 20,
            }

            local state = Winstate.msconfig_to_winstate(config)

            eq(state.wintype, 'horizontal')
            eq(state.height, 20)
            eq(state.width, nil)
        end)

        it("errors on invalid wintype", function()
            local config = {
                wintype = 'invalid',
            }

            assert.has_error(function()
                Winstate.msconfig_to_winstate(config)
            end, "Invalid wintype")
        end)
    end)

    describe("winstate_to_winconfig conversions", function()
        it("converts float state to vim config", function()
            local state = {
                wintype = 'float',
                row = 5,
                col = 10,
                width = 60,
                height = 30,
            }

            local config = Winstate.winstate_to_winconfig(state)

            eq(config.relative, 'editor')
            eq(config.row, 5)
            eq(config.col, 10)
            eq(config.width, 60)
            eq(config.height, 30)
        end)

        it("converts vertical split state to vim config", function()
            local state = {
                wintype = 'vertical',
                width = 50,
            }

            local config = Winstate.winstate_to_winconfig(state)

            eq(config.width, 50)
            eq(config.vertical, true)
            eq(config.relative, nil)
        end)

        it("converts horizontal split state to vim config", function()
            local state = {
                wintype = 'horizontal',
                height = 25,
            }

            local config = Winstate.winstate_to_winconfig(state)

            eq(config.height, 25)
            eq(config.vertical, false)
            eq(config.relative, nil)
        end)

        it("uses default data when no state provided", function()
            -- Should use the default config's window settings
            local config = Winstate.winstate_to_winconfig()

            assert.not_nil(config)
            -- Check it returns valid config based on default
            if config.relative then
                eq(config.relative, 'editor')
            else
                assert.not_nil(config.vertical)
            end
        end)
    end)

    describe("winconfig_to_winstate conversions", function()
        it("converts float vim config to state", function()
            local config = {
                relative = 'editor',
                row = 8,
                col = 12,
                width = 70,
                height = 35,
            }

            local state = Winstate.winconfig_to_winstate(config)

            eq(state.wintype, 'float')
            eq(state.row, 8)
            eq(state.col, 12)
            eq(state.width, 70)
            eq(state.height, 35)
        end)

        it("converts vertical split vim config to state", function()
            local config = {
                vertical = true,
                split = 'right',
                width = 45,
                height = nil,
                relative = "",
            }

            local state = Winstate.winconfig_to_winstate(config)

            eq('vertical', state.wintype)
            eq(45, state.width)
        end)

        it("converts horizontal split vim config to state", function()
            local config = {
                vertical = false,
                height = 20,
                width = nil,
            }

            local state = Winstate.winconfig_to_winstate(config)

            eq(state.wintype, 'horizontal')
            eq(state.height, 20)
        end)
    end)

    describe("helper functions", function()
        it("is_float identifies float windows", function()
            eq(Winstate.is_float({ wintype = 'float' }), true)
            eq(Winstate.is_float({ wintype = 'vertical' }), false)
            eq(Winstate.is_float({ wintype = 'horizontal' }), false)
        end)

        it("is_vertical identifies vertical splits", function()
            eq(Winstate.is_vertical({ wintype = 'vertical' }), true)
            eq(Winstate.is_vertical({ wintype = 'float' }), false)
            eq(Winstate.is_vertical({ wintype = 'horizontal' }), false)
        end)

        it("is_horizontal identifies horizontal splits", function()
            eq(Winstate.is_horizontal({ wintype = 'horizontal' }), true)
            eq(Winstate.is_horizontal({ wintype = 'float' }), false)
            eq(Winstate.is_horizontal({ wintype = 'vertical' }), false)
        end)
    end)

    describe("metatable behavior", function()
        it("metatable __index returns correct values", function()
            local config = {
                wintype = 'float',
                height = 25,
                width = 75,
                float_y = 5,
                float_x = 10,
            }

            Winstate.update_config(config)

            local state = setmetatable({}, Winstate.mt)

            eq(state.wintype, 'float')
            eq(state.height, 25)
            eq(state.width, 75)
            eq(state.row, 5)
            eq(state.col, 10)
        end)

        it("metatable __newindex validates keys", function()
            -- Set a no-op callback to avoid the default error callback
            Winstate.set_callback(function(_)
                -- Just a no-op callback for testing
            end)

            local config = {
                wintype = 'float',
                height = 25,
                width = 75,
                float_y = 5,
                float_x = 10,
            }

            Winstate.update_config(config)

            local state = setmetatable({}, Winstate.mt)

            -- Valid key update should work
            assert.no_error(function()
                state.row = 15
            end)

            -- Invalid key should error
            assert.has_error(function()
                state.invalid_key = 100
            end, "invalid entry 'invalid_key'")
        end)

        it("metatable __newindex triggers callback", function()
            local callback_called = false
            ---@type ms.winstate
            local callback_data = nil

            Winstate.set_callback(function(data)
                callback_called = true
                callback_data = data
            end)

            local config = {
                wintype = 'float',
                height = 25,
                width = 75,
                float_y = 5,
                float_x = 10,
            }

            Winstate.update_config(config)

            local state = setmetatable({}, Winstate.mt)
            state.row = 20

            eq(callback_called, true)
            assert.not_nil(callback_data)
            eq(callback_data.row, 20)
        end)
    end)

    describe("round-trip conversions", function()
        it("float config survives round trip", function()
            local original_config = {
                wintype = 'float',
                height = 30,
                width = 90,
                float_y = 12,
                float_x = 18,
            }

            local state = Winstate.msconfig_to_winstate(original_config)
            local vim_config = Winstate.winstate_to_winconfig(state)
            local back_to_state = Winstate.winconfig_to_winstate(vim_config)

            eq(back_to_state.wintype, 'float')
            eq(back_to_state.height, 30)
            eq(back_to_state.width, 90)
            eq(back_to_state.row, 12)
            eq(back_to_state.col, 18)
        end)

        it("vertical split survives round trip", function()
            local original_config = {
                wintype = 'split',
                vertical = true,
                width = 55,
            }

            local state = Winstate.msconfig_to_winstate(original_config)
            local vim_config = Winstate.winstate_to_winconfig(state)
            local back_to_state = Winstate.winconfig_to_winstate(vim_config)

            eq(back_to_state.wintype, 'vertical')
            eq(back_to_state.width, 55)
        end)
    end)
end)
