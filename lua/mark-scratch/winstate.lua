local Config = require('mark-scratch.config')
local Logg = require('mark-scratch.logger').logg
local Winbuf = require('mark-scratch.winbuf')
local Utils = require('mark-scratch.utils')

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
            height = config.height,
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
        ret = { height = state.height, vertical = false, split = 'below' }
    elseif is_vertical(state) then
        ret = { width = state.width, vertical = true, split = 'right' }
    else
        Logg:log("Invalid windowtype: ", state)
        error("Invalid wintype")
    end

    Logg:log("Current state: ", state, "After conversion: ", ret)

    return ret
end

---@param cfg vim.api.keyset.win_config
---@return ms.winstate
function M.winconfig_to_winstate(cfg)
    ---@type ms.winstate
    local ret

    if not cfg.relative or cfg.relative == "" then
        if cfg.split == 'left' or cfg.split == 'right' then
            ret = {
                wintype = 'vertical',
                width = cfg.width,
            }
        else
            ret =  {
                wintype = 'horizontal',
                height = cfg.height,
            }
        end
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

---@param cfg vim.api.keyset.win_config
function M.save_winconfig(cfg)
    local ws = M.winconfig_to_winstate(cfg)

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
            Logg:log(("Tried to set invalid '%s' to '%s'"):format(k, tostring(v)), data)
            error(("invalid entry '%s'"):format(k))
        else
            if k == 'wintype' and data[k] ~= v then
                Logg:log("Switching wintypes from " .. data[k] .. " to " .. v)

                if v == 'float' then
                    M.prev_split = vim.fn.deepcopy(data)
                    data = vim.tbl_deep_extend('force', data, M.prev_float)
                else
                    M.prev_float = vim.fn.deepcopy(data)
                    data = vim.tbl_deep_extend('force', data, M.prev_split)
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

---@param bufnr integer
---@param resp string[]
local function prompt_set_response(bufnr, resp)
    local lines = vim.api.nvim_buf_line_count(bufnr)
    local insert_line = lines - 1

    vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, resp)
end

local function prompt_lines()
    local lines = {
        "Enter 'h' for help",
        "",
        "Provide the name of the setting to change and it's value.",
        "Ex:",
        "   wintype float",
        "   height 50",
        "",
        "State:",
        ("| wintype: %s"):format(data.wintype)
    }

    if is_float(data) then
        local flines = {
            "| row: "    .. data.row,
            "| col: "    .. data.col,
            "| width: "  .. data.width,
            "| height: " .. data.height,
        }
        table.move(flines, 1, #flines, #lines + 1, lines)
    elseif is_horizontal(data) then
        local hlines = {
            "| height: " .. data.height,
        }
        table.insert(lines, hlines[1])
    elseif is_vertical(data) then
        local vlines = {
            "| width: "  .. data.width,
        }
        table.insert(lines, vlines[1])
    else
        error("Invalid wintype: " .. data.wintype)
    end

    table.insert(lines, "============================")

    return lines
end

---@param bufnr integer
---@param text string
local function apply_user_input(bufnr, text)

    ---@type ms.winstate
    local st = setmetatable({}, M.mt)

    local trimmed = text:match("^%s*(.-)%s*$")
    if not trimmed then
        Logg:log(("trimming text returned nil. '%s'"):format(text))
        prompt_set_response(bufnr, { "Invalid input, be better this time" })
        return
    end

    local k, v = trimmed:match("^(%w+)[^%w]+(%w+)$")
    if not k or not v then
        Logg:log(("matching key and value returned nil. '%s'"):format(trimmed))
        prompt_set_response(bufnr, { "Invalid input, be better this time" })
        return
    end

    if k ~= 'wintype' then
        v = tonumber(v)
    end

    Logg:log(("Setting '%s' to '%s' from promp buffer"):format(k, v))

    st[k] = v

    vim.bo[bufnr].modified = false
end

local bufnr = -1
local winid = nil
local count = 0

function M.open_settings_window()
    if winid and vim.api.nvim_win_is_valid(winid) then
        return
    end

    count = count + 1

    local name = ("[winsettings | %s | %s]")
        :format(Utils.tostrings(os.time(), count))
    local cfg = Config.default_config.window

    bufnr, winid = Winbuf
        :new({ name = name })
        :bufopt({
            ['buftype']   = 'prompt',
            ['swapfile']  = false,
            ['bufhidden'] = 'wipe',
            ['buflisted'] = false,
            ['modified'] = false
        })
        :win('float')
        :winsetconf({
            row = cfg.float_y,
            col = cfg.float_x,
            width = 80,
            height = 45,
            title = 'mark-scratch settings'
        })
        :info()

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, prompt_lines())

    vim.fn.prompt_setprompt(bufnr, '> ')
    vim.fn.prompt_setcallback(bufnr, function(text)
        apply_user_input(bufnr, text)
        vim.bo[bufnr].modified = false
    end)
    vim.fn.prompt_setinterrupt(bufnr, function()
        vim.api.nvim_win_close(winid, true)
    end)

    vim.keymap.set('n', 'q', function()
        vim.api.nvim_win_close(winid, true)
    end, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        nowait = true
    })


    vim.bo[bufnr].modified = false
end

return M
