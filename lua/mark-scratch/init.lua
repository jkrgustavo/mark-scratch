local Utils = require("mark-scratch.utils")
local MSGroup = require("mark-scratch.augroup")
local Msp = require('mark-scratch.lsp')
local Logg = require('mark-scratch.logger').logg
local Config = require('mark-scratch.config')
local Ui = require('mark-scratch.ui')

---@class Scratch
---@field initialized boolean
---@field config ms.config
---@field lsp msp
---@field ui Ui
local Scratch = {}

Scratch.__index = Scratch

function Scratch.new()
    local config = Config.default_config

    return setmetatable({
        initialized = false,
        config = config,
        lsp = Msp.new(config),
        ui = Ui.new(config)
    }, Scratch)
end

---@return boolean
---@param silent? boolean
function Scratch:validate(silent)

    if not self.initialized then
        if not silent then error("Uninitialized", 2) end
        return false
    end

    for k, v in pairs(self) do
        if (not v or v == -1) and k ~= "windnr" then
            if not silent then error("[" .. k .. "] is uninitialized/invalid", 2) end
            return false
        end
    end

    if not self.ui:validate() then
        if not silent then error("Invalid ui") end
        return false
    end

    if not self.lsp:validate(self.ui.bufnr, { started = true }) then
        if not silent then error("Lsp isn't attached to buffer", 2) end
        return false
    end

    if #vim.api.nvim_get_autocmds({ group = MSGroup }) == 0 and not self.initialized then
        if not silent then error("No autocommands are setup", 2) end
        return false
    end

    return true
end

function Scratch:destroy()
    if not self.initialized then
        Logg:log("Tried to destroy while 'self.initialized' was false")
        return
    end

    local bufnr = self.ui.bufnr

    Logg:log("Destroying scratch")

    pcall(vim.api.nvim_clear_autocmds, { group = MSGroup })
    pcall(vim.api.nvim_del_augroup_by_id, MSGroup)

    vim.treesitter.stop(bufnr)

    self.lsp:stop_lsp(bufnr)
    self.ui:shutdown()

    local clean = Utils.wait_until(function()
        local no_open_portals = #vim.fn.win_findbuf(bufnr) == 0
        local lsp_not_attached = self.lsp:validate(bufnr, { stopped = true })
        local aug_is_ok = pcall(vim.api.nvim_get_autocmds, { group = MSGroup })

        if not no_open_portals and not lsp_not_attached and aug_is_ok then
            Logg:log("while waiting" .. ("windows: %s | lsp: %s | aug: %s")
                 :format(Utils.tostrings(no_open_portals, lsp_not_attached, not aug_is_ok)))
        end

        return no_open_portals and lsp_not_attached and not aug_is_ok
    end)

    if not clean then
        Logg:log("'clean' was false", self)
        error("unable cleanup resources")
    end

    assert(Utils.wait_until(function()
        return not vim.api.nvim_buf_is_valid(bufnr)
    end))

    Logg:log("Destroyed")
    self.initialized = false
end

---@param config? ms.config.partial
function Scratch:setup(config)
    config = config or {}

    if self.initialized then
        Logg:log("attempt to re-initialize", self)
        return
    end


    self.config = vim.tbl_deep_extend('force', self.config, config)

    self.ui:setup(config)
    self.lsp:start_lsp(self.ui.bufnr)
    self.initialized = true

    vim.api.nvim_create_user_command("MSDest", function()
        self:destroy()
    end, { desc = "Destroy a buffer" })

    vim.api.nvim_create_autocmd({ "VimLeavePre"}, {
        buffer = self.ui.bufnr,
        group = MSGroup,
        once = true,
        callback = function() self:destroy() end,
    })


    assert(self:validate(), "End of setup")
end

return Scratch.new()

--[[ TODO:

    - better config
    - save to a file
    - move lsp to be part of ui
    - Convert modules to singletons
    - Refactor
    - Top-level split or relative to current window
    - Flesh out winstate more

--]]

