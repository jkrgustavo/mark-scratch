local Winbuf = require('mark-scratch.winbuf')
local Logg = require('mark-scratch.logger').logg
local MSGroup = require('mark-scratch.augroup')
local Utils = require('mark-scratch.utils')
local Config = require('mark-scratch.config')
local Msp = require('mark-scratch.lsp')
local Winstate = require('mark-scratch.winstate')

---@param mui Ui
local function make_commands_and_keybinds(mui)

    vim.api.nvim_create_user_command("MSOpen", function()
        mui:open_window()
    end, { desc = "Open scratch window" })

    vim.api.nvim_create_user_command("MSClose", function()
        mui:close_window()
    end, { desc = "Close scratch window" })

    vim.api.nvim_create_user_command('MSTogg', function()
        mui:toggle_window()
    end, { desc = "Toggle scratch window"})

    vim.api.nvim_create_user_command("MSDest", function()
        require('mark-scratch'):destroy()
    end, { desc = "Clean resources and un-initialize everything" })

    vim.api.nvim_create_user_command("MSWrite", function()
        require('mark-scratch').file:save()
    end, { desc = "Clean resources and un-initialize everything" })

    local kbind = mui.config.keybinds
    vim.keymap.set('n', kbind.float_up, function()
        mui.state.row = mui.state.row - 5
    end)
    vim.keymap.set('n', kbind.float_down, function()
        mui.state.row = mui.state.row + 5
    end)
    vim.keymap.set('n', kbind.float_left, function()
        mui.state.col = mui.state.col - 10
    end)
    vim.keymap.set('n', kbind.float_right, function()
        mui.state.col = mui.state.col + 10
    end)

    vim.keymap.set('n', kbind.toggle_scratch, function()
        mui:toggle_window()
    end)

    vim.keymap.set('n', kbind.toggle_menu, Winstate.toggle_settings_window)

    Logg:log("usercommands and keybinds setup")
end

---@class Ui
---@field lsp msp
---@field windnr integer | nil
---@field config ms.config
---@field initialized boolean
---@field state ms.winstate
local ui = {}
ui.__index = ui

---@return Ui
local function new()

    local instance = {
        windnr = nil,
        config = Config.default_config,
        initialized = false,
        lsp = Msp,
    }

    instance.state = setmetatable({}, Winstate.mt(function(d)
        if instance.windnr and vim.api.nvim_win_is_valid(instance.windnr) then
            local wincfg = Winstate.winstate_to_winconfig(d)
            vim.api.nvim_win_set_config(instance.windnr, wincfg)
        end
    end))

    return setmetatable(instance, ui)
end

local instance = new()

function ui:validate()
    local bufnr = require('mark-scratch').file.bufnr

    local valid = self.initialized
        and (not self.windnr or vim.api.nvim_win_is_valid(self.windnr))
        and vim.api.nvim_buf_is_valid(bufnr)

    if not valid then
        Logg:log(
            "validate failed:",
            self.initialized,
            self.windnr,
            self.windnr and vim.api.nvim_win_is_valid(self.windnr) or false,
            vim.api.nvim_buf_is_valid(bufnr),
            self.lsp:validate(bufnr, { started = true }))
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
        make_commands_and_keybinds(self)

        if not self.config.file_overrides_cfg then
            Winstate.update_winstate(self.config.window)
        end

        self.lsp:start_lsp(require("mark-scratch").file.bufnr)

        self.initialized = true
        Logg:log("Initialied ui")
    end

end

function ui:open_window()
    local bufnr = require('mark-scratch').file.bufnr

    if not self:validate() then
        Logg:log("Open window called with invalid ui")
        return
    end

    if self.windnr and vim.api.nvim_win_is_valid(self.windnr) then
        Logg:log("double open")
        return
    end

    local wintype = self.state.wintype == 'float' and 'float' or 'split'
    self.windnr = Winbuf
        :new({ bufnr = bufnr })
        :win(wintype)
        :winsetconf(Winstate.winstate_to_winconfig())
        :winopt({
            ['wrap'] = true,
            ['conceallevel'] = 2
        })
        :wininfo()

    Logg:log(
        ("Opened new '%s', winconfig: "):format(wintype),
        Winstate.winstate_to_winconfig())
end

function ui:close_window()
    local winid = self.windnr

    if self.is_closing or not winid or not vim.api.nvim_win_is_valid(winid) then
        Logg:log("double close")
        self.windnr = nil
        return
    end
    self.is_closing = true

    -- Save current window state in case the user resized/moved it themselves
    local nvwincfg = vim.api.nvim_win_get_config(winid)
    Winstate.save_winconfig(nvwincfg)

    local ok, err = pcall(vim.api.nvim_win_close, winid, false)
    if not ok then
        Logg:log("Errror while closing window: ", err)
        error("Unable to close window")
    end

    self.windnr = nil

    self.is_closing = false
end

function ui:toggle_window()
    if self.windnr and vim.api.nvim_win_is_valid(self.windnr) then
        self:close_window()
    else
        self:open_window()
    end
end

function ui:shutdown()
    if not self.initialized then
        Logg:log("double shutdown")
        return
    end

    local bufnr = require('mark-scratch').file.bufnr

    local buf_portals = vim.fn.win_findbuf(bufnr)
    if #buf_portals > 0 then
        for _, p in ipairs(buf_portals) do
            local ok, err = pcall(vim.api.nvim_win_close, p, true)
            if not ok then
                Logg:log("Error while calling win_close: " .. err)
            end
        end
    end
    self.windnr = nil

    self.lsp:stop_lsp(bufnr)
    Utils.wait_until(function()
        return self.lsp:validate(bufnr, { stopped = true })
    end)

    pcall(vim.api.nvim_clear_autocmds, { group = MSGroup })
    pcall(vim.api.nvim_del_user_command, 'MSOpen')
    pcall(vim.api.nvim_del_user_command, 'MSClose')
    pcall(vim.api.nvim_del_user_command, 'MSTogg')

    Logg:log("Finished destroying ui")
    self.initialized = false
end

return instance
