local Config = require('mark-scratch.config')
local Logg = require('mark-scratch.logger').logg

local M = {}

---@alias WindowType 'float' | 'horizontal' | 'vertical'

---@class ms.winstate.base
---@field wintype WindowType

---@class ms.winstate.split.vertical : ms.winstate.base
---@field wintype 'vertical'
---@field width integer

---@class ms.winstate.split.horizontal : ms.winstate.base
---@field wintype 'horizontal'
---@field height integer

---@class ms.winstate.float : ms.winstate.base
---@field wintype 'float'
---@field row integer
---@field col integer
---@field width integer
---@field height integer

---@alias ms.winstate ms.winstate.float | ms.winstate.split.vertical | ms.winstate.split.horizontal

---@param settings ms.winstate
---@return boolean
local function is_float(settings)
    return settings.wintype == 'float'
end


---@param settings ms.winstate
---@return boolean
local function is_vertical(settings)
    return settings.wintype == 'vertical'
end

---@param settings ms.winstate
---@return boolean
local function is_horizontal(settings)
    return settings.wintype == 'horizontal'
end

---@param config ms.config.window
---@return ms.winstate
function M.msconfig_to_winstate(config)
    local wintype
    local ret = {}
    if config.wintype == 'float' then
        wintype = 'float'
        ---@type ms.winstate.float
        ret = {
            wintype = wintype,
            height = config.height,
            width = config.width,
            row = config.float_y,
            col = config.float_x,
        }
    elseif config.wintype == 'split' and config.vertical then
        wintype = 'vertical'
        ---@type ms.winstate.split.vertical
        ret = {
            wintype = wintype,
            width = config.width,
        }
    elseif config.wintype == 'split' and not config.vertical then
        wintype = 'horizontal'
        ---@type ms.winstate.split.horizontal
        ret = {
            wintype = wintype,
            height = config.width,
        }
    else
        Logg:log("Invalid wintype set: ", config)
        error("Invalid wintype")
    end

    return ret
end

---@type ms.winstate
local data = M.msconfig_to_winstate(Config.default_config.window)

---@param state? ms.winstate
---@return vim.api.keyset.win_config
--- When state is not provided this function uses the private
--- state within the winstate module. Otherwise performs the
--- conversion on the provided state
function M.winstate_to_winconfig(state)
    ---@type vim.api.keyset.win_config
    local ret

    state = state or data

    if is_float(state) then
        ret = {
            relative = 'editor',
            row = state.row,
            col = state.col,
            width = state.width,
            height = state.height
        }
    elseif is_horizontal(state) then
        ret = { height = state.height, vertical = false, }
    elseif is_vertical(state) then
        ret = { width = state.width, vertical = true }
    else
        Logg:log("Invalid windowtype: ", state)
        error("Invalid wintype")
    end

    return ret
end

---@param cfg vim.api.keyset.win_config
---@return ms.winstate
function M.winconfig_to_winstate(cfg)
    ---@type ms.winstate
    local ret

    if not cfg.relative or cfg.relative == "" then
        ret = cfg.vertical
            and {
                wintype = 'vertical',
                width = cfg.width,
                vertical = cfg.vertical,
            }
            or {
                wintype = 'horizontal',
                height = cfg.height,
                vertical = cfg.vertical,
            }
    else
        ret = {
            wintype = 'float',
            height = cfg.height,
            width = cfg.width,
            row = cfg.row,
            col = cfg.col,
        }
    end

    return ret
end

---@param cfg ms.config.window
function M.update_config(cfg)
    local ws = M.msconfig_to_winstate(cfg)
    for k, v in pairs(ws) do
        data[k] = v
    end
end

---@param dt ms.winstate
local on_change = function(dt)
    error("newindex called: " .. vim.inspect(dt))
end

---@param cb fun(dt: ms.winstate)
--- Set the callback used when '__newindex' is called
function M.set_callback(cb)
    on_change = cb
end

M.mt = {
    __index = function(_, k)
        local ret = data[k]
        return ret
    end,
    __newindex = function(_, k, v)
        if not data[k] then
            -- vim.notify('within newindex', 4)
            Logg:log("Tried to set invalid ui state", k, v)
            error(("invalid entry '%s'"):format(k))
        else
            if k == 'wintype' and data[k] ~= v then
                Logg:log("Switching wintypes")

                if v == 'float' then
                    M.prev_split = vim.fn.deepcopy(data)
                    data = vim.fn.deepcopy(M.prev_float)
                else
                    M.prev_float = vim.fn.deepcopy(data)
                    data = vim.fn.deepcopy(M.prev_split)
                end
            end

            data[k] = v

            on_change(data)
        end

    end
}

M.prev_float = M.msconfig_to_winstate(
    vim.tbl_deep_extend('force', Config.default_config.window, { wintype = 'float' }))
M.prev_split = M.msconfig_to_winstate(
    vim.tbl_deep_extend('force', Config.default_config.window, { wintype = 'split' }))

M.is_float = is_float
M.is_horizontal = is_horizontal
M.is_vertical = is_vertical

return M
