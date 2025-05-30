local Winbuf = require('mark-scratch.winbuf')
local Logg = require('mark-scratch.logger').logg
local MSGroup = require('mark-scratch.augroup')

local FTYPE = "scratchmarkdown"

---@class Ui
---@field bufnr integer
---@field windnr integer | nil
---@field config ms.config.window
---@field initialized boolean
local ui = {}
ui.__index = ui

---@param config ms.config.window
---@return Ui
function ui.new(config)

    return setmetatable({
        bufnr = -1,
        windnr = nil,
        config = config,
        initialized = false,
    }, ui)
end

---@param mui Ui
local function make_commands(mui)

    vim.api.nvim_create_autocmd({ "VimLeavePre"}, {
        buffer = mui.bufnr,
        group = MSGroup,
        once = true,
        callback = function() mui:shutdown() end
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
        buffer = mui.bufnr,
        once = false,
        group = MSGroup,
        callback = function() mui:close_window() end
    })

    vim.api.nvim_create_autocmd({ "BufHidden" }, {
        buffer = mui.bufnr,
        once = true,
        group = MSGroup,
        callback = function() mui:close_window() end
    })

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        buffer = mui.bufnr,
        once = false,
        group = MSGroup,
        callback = function()
            if mui.windnr and not vim.api.nvim_win_is_valid(mui.windnr) then
                mui.windnr = nil
            end
        end
    })


    vim.api.nvim_create_user_command("MSOpen", function()
        mui:open_window()
    end, { desc = "Open scratch window"})

    vim.api.nvim_create_user_command("MSClear", function()
        mui:set_contents({})
    end, { desc = "Clear scratch window"})

    vim.api.nvim_create_user_command("MSClose", function()
        mui:close_window()
    end, { desc = "Close scratch window"})

    vim.api.nvim_create_user_command("MSLogg", function()
        Logg:show()
    end, { desc = "Close scratch window"})

    Logg:log("user/autocommands setup")

end

local count = 0

---@param u Ui
local function init(u)
    count = count + 1
    local buf_name = "[Note" .. "|" .. count .. "|" .. os.time() .. "|" .. math.random(1000) .. "].md"

    u.bufnr = Winbuf
        :new({ name = buf_name, scratch = true })
        :bufopt({
            ['filetype'] = FTYPE,
            ['tabstop'] = 2,
            ['shiftwidth'] = 2
        })
        :bufinfo()

    Logg:log(
        "new buffer",
        "name: " .. buf_name,
        "id: " .. tostring(u.bufnr))

    make_commands(u)

    u.initialized = true
    Logg:log("Initialied ui")
end

function ui:validate()
    local wvalid = self.windnr and vim.api.nvim_win_is_valid(self.windnr) or true

    return self.initialized and wvalid and vim.api.nvim_buf_is_valid(self.bufnr)
end

---@param config ms.config.partial.window
---
function ui:setup(config)
    Logg:log("Changed from default config", config)

    config = config or {}
    self.config = vim.tbl_deep_extend('force', self.config, config)

    if not self.initialized then
        init(self)
    end
end

function ui:open_window()
    if not self.initialized then
        Logg:log("Open window called while uninitialized")
    end

    if self.windnr and vim.api.nvim_win_is_valid(self.windnr) then
        Logg:log("double open")
        return
    end

    local cfg = self.config
    if cfg.wintype == 'float' then
        self.windnr = Winbuf
            :new({ bufnr = self.bufnr })
            :float({
                width = cfg.width,
                height = cfg.height,
                row = cfg.float_y,
                col = cfg.float_x,
            })
            :winopt({
                ['wrap'] = true,
                ['conceallevel'] = 2
            })
            :wininfo()
    elseif cfg.wintype == 'split' then
        self.windnr = Winbuf
            :new({ bufnr = self.bufnr })
            :split({
                split = cfg.split_direction,
                vertical = cfg.vertical
            })
            :winopt({
                ['wrap'] = true,
                ['conceallevel'] = 2
            })
            :wininfo()
    end

    Logg:log("opened new " .. cfg.wintype)
end

function ui:close_window()
    if not self.windnr or not vim.api.nvim_win_is_valid(self.windnr) then
        Logg:log("double close")
        self.windnr = nil
        return
    end

    local winid = self.windnr or -1
    local ok, err = pcall(vim.api.nvim_win_close, winid, false)
    if not ok then
        Logg:log("Errror while closing window: ", err)
        return
    end

    vim.schedule(function()
        if not vim.api.nvim_win_is_valid(winid) then
            Logg:log("closing the window")
            self.windnr = nil
        end
    end)

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

    if vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.bo[self.bufnr].buflisted = false
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    Logg:log("Finished destroying ui")
    self.initialized = false
    self.bufnr = -1
end

function ui:set_contents(lines)
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
end

return ui
