local Winbuf = require('mark-scratch.winbuf')
local Logg = require('mark-scratch.logger').logg
local MSGroup = require('mark-scratch.augroup')
local Utils = require('mark-scratch.utils')
local Config = require('mark-scratch.config')
local Msp = require('mark-scratch.lsp')
local Winstate = require('mark-scratch.winstate')
--
-- ---@param cfg ms.config
-- ---@return Ui
-- local function data_setup(cfg)
--     local config = instance.config
--     instance.__data = {
--         col = config.window.float_x,
--         row = config.window.float_y,
--         width = config.window.width,
--         height = config.window.height,
--         split = config.window.wintype == 'split'
--     }
--     instance.state = setmetatable({}, {
--         __index = function(_, k)
--             local ret = instance.__data[k]
--             Logg:log("index called", k, ret)
--             return ret
--         end,
--         __newindex = function(_, k, v)
--             Logg:log("newindex called: " .. k .. ' ' .. tostring(v))
--             if not instance.__data[k] then
--                 Logg:log("Tried to set invalid ui state", k, v)
--                 error(("invalid entry '%s'"):format(k))
--             else
--                 instance.__data[k] = v
--                 if instance.windnr then
--                     Logg:log("updating winconfig too")
--
--                     local relative = not instance.__data.split and 'editor' or nil
--
--                     vim.api.nvim_win_set_config(instance.windnr, {
--                         relative = relative,
--                         row = instance.__data.row,
--                         col = instance.__data.col,
--                         width = instance.__data.width,
--                         height = instance.__data.height
--                     })
--                 end
--             end
--
--         end
--     })
--
--     return instance
-- end
--

---@param mui Ui
local function make_commands(mui)

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        buffer = mui.bufnr,
        once = false,
        group = MSGroup,
        callback = function(e)
            if mui.config.window.close_on_leave then
                Logg:log("Callback triggered: ", e)
                mui:close_window()
            end
        end
    })

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        buffer = mui.bufnr,
        once = false,
        group = MSGroup,
        callback = function(e)
            if mui.windnr then
                if vim.api.nvim_win_is_valid(mui.windnr) then
                    mui:close_window()
                else
                    mui.windnr = nil
                end
            end
            Logg:log("Callback triggered: ", e)
        end
    })

    vim.api.nvim_create_user_command("MSOpen", function()
        mui:open_window()
    end, { desc = "Open scratch window" })

    vim.api.nvim_create_user_command("MSClear", function()
        mui:set_contents({})
    end, { desc = "Clear scratch window" })

    vim.api.nvim_create_user_command("MSClose", function()
        mui:close_window()
    end, { desc = "Close scratch window" })


    Logg:log("user/autocommands setup")

end

---@param u Ui
local function make_keybinds(u)
    vim.keymap.set('n', u.config.keybinds.float_up, function()
        u.state.row = u.state.row - 5
    end)
    vim.keymap.set('n', u.config.keybinds.float_down, function()
        u.state.row = u.state.row + 5
    end)
    vim.keymap.set('n', u.config.keybinds.float_left, function()
        u.state.col = u.state.col - 5
    end)
    vim.keymap.set('n', u.config.keybinds.float_right, function()
        u.state.col = u.state.col + 5
    end)

    vim.keymap.set('n', u.config.keybinds.open_scratch, function()
        u:open_window()
    end)

end

local count = 0

---@param u Ui
local function init(u)
    count = count + 1
    local buf_name = "[Note" .. "|" .. count .. "|" .. os.time() .. "|" .. math.random(1000) .. "].md"

    u.bufnr = Winbuf
        :new({ name = buf_name, scratch = true })
        :bufopt({
            ['filetype'] = 'scratchmarkdown',
            ['tabstop'] = 2,
            ['shiftwidth'] = 2
        })
        :bufinfo()

    Logg:log(
        "new buffer",
        "name: " .. buf_name,
        "id: " .. tostring(u.bufnr))

    make_commands(u)
    make_keybinds(u)
    Winstate.update_config(u.config.window)
    u.lsp:start_lsp(u.bufnr)

    u.initialized = true
    Logg:log("Initialied ui")
end


---@class Ui
---@field lsp msp
---@field bufnr integer
---@field windnr integer | nil
---@field config ms.config
---@field initialized boolean
---@field state ms.winstate
local ui = {}
ui.__index = ui

---@return Ui
local function new()

    local instance = {
        bufnr = -1,
        windnr = nil,
        config = Config.default_config,
        initialized = false,
        lsp = Msp,
        state = setmetatable({}, Winstate.mt)
    }

    Winstate.set_callback(function(d)
        if instance.windnr and vim.api.nvim_win_is_valid(instance.windnr) then
            vim.api.nvim_win_set_config(instance.windnr, Winstate.winstate_to_winconfig(d))
        end
    end)

    return setmetatable(instance, ui)
end

local instance = new()

function ui:validate()
    local valid = self.initialized
        and (not self.windnr or vim.api.nvim_win_is_valid(self.windnr))
        and vim.api.nvim_buf_is_valid(self.bufnr)
        and self.lsp:validate(self.bufnr, { started = true })

    if not valid then
        Logg:log(
            "validate failed:",
            self.initialized,
            self.windnr,
            self.windnr and vim.api.nvim_win_is_valid(self.windnr) or false,
            vim.api.nvim_buf_is_valid(self.bufnr),
            self.lsp:validate(self.bufnr, { started = true }))
    end

    return valid
end

---@param config? ms.config.partial
function ui:setup(config)
    if config then Logg:log("Changed from default config", config) end

    if self ~= instance then
        self = instance
    end

    config = config or {}

    self.config = vim.tbl_deep_extend('force', self.config, config)

    if not self.initialized then
        init(self)
    end

end

function ui:open_window()
    if not self:validate() then
        Logg:log("Open window called with invalid ui")
        return
    end

    if self.windnr and vim.api.nvim_win_is_valid(self.windnr) then
        Logg:log("double open")
        return
    end

    local cfg = Winstate.winstate_to_winconfig()

    self.windnr = Winbuf
        :new({ bufnr = self.bufnr })
        :win(self.state.wintype == 'float' and 'float' or 'split')
        :winsetconf(cfg)
        :winopt({
            ['wrap'] = true,
            ['conceallevel'] = 2
        })
        :wininfo()

end


function ui:close_window()
    if not self.windnr or not vim.api.nvim_win_is_valid(self.windnr) then
        Logg:log("double close")
        self.windnr = nil
        return
    end

    local winid = self.windnr or -1 -- to make lua_ls relax

    -- Save current window state in case the user resized/moved it themselves
    local wstate = Winstate.winconfig_to_winstate(vim.api.nvim_win_get_config(winid))
    for k, _ in pairs(wstate) do
        self.state[k] = wstate[k]
    end

    local ok, err = pcall(vim.api.nvim_win_close, winid, false)
    if not ok then
        Logg:log("Errror while closing window: ", err)
        return
    end

    Logg:log("closing the window")
    self.windnr = nil

end

function ui:shutdown()
    if not self.initialized then
        Logg:log("double shutdown")
        return
    end

    local buf_portals = vim.fn.win_findbuf(self.bufnr)
    if #buf_portals > 0 then
        for _, p in ipairs(buf_portals) do
            local ok, err = pcall(vim.api.nvim_win_close, p, true)
            if not ok then
                Logg:log("Error while calling win_close: " .. err)
            end
        end
    end
    self.windnr = nil

    self.lsp:stop_lsp(self.bufnr)
    Utils.wait_until(function()
        return self.lsp:validate(self.bufnr, { stopped = true })
    end)

    if vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.bo[self.bufnr].buflisted = false
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    local shutdown = Utils.wait_until(function()
        return not vim.api.nvim_buf_is_valid(self.bufnr)
    end)

    if not shutdown then
        Logg:log("timeout waiting for 'buf_is_valid' to return false", self)
    end

    Logg:log("Finished destroying ui")
    self.initialized = false
    self.bufnr = -1
end

function ui:set_contents(lines)
    if not vim.api.nvim_buf_is_valid(self.bufnr) then
        error("Invalid buffer")
        Logg:log("Tried to set contents on an invalid buffer", lines)
    end

    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
end


return instance
