local Utils = require("mark-scratch.utils")
local MSGroup = require("mark-scratch.augroup")
-- local Msp = require('mark-scratch.lsp')
local Logg = require('mark-scratch.logger').logg
local Config = require('mark-scratch.config')
local Ui = require('mark-scratch.ui')

---@class Scratch
---@field initialized boolean
---@field config ms.config
---@field ui Ui
local Scratch = {}
Scratch.__index = Scratch

local function new()
    local config = Config.default_config

    return setmetatable({
        initialized = false,
        config = config,
        ui = Ui
    }, Scratch)
end

local instance = new()

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

    self.ui:shutdown()

    local augroup_clean = Utils.wait_until(function()
        return not pcall(vim.api.nvim_get_autocmds, { group = MSGroup })
    end)

    if not augroup_clean then
        Logg:log("Augroup wasnt cleaned", self)
        error("unable cleanup resources")
    end

    assert(Utils.wait_until(function()
        return not vim.api.nvim_buf_is_valid(bufnr)
    end), "Buffer wasn't destroyed")

    Logg:log("Destroyed")
    self.initialized = false
end

---@param config? ms.config.partial
function Scratch:setup(config)
    config = config or {}

    if self ~= instance then
        Logg:log("Swapping instances")
        self = instance
    end

    if self.initialized then
        Logg:log("attempt to re-initialize", self)
        return
    end

    self.config = vim.tbl_deep_extend('force', self.config, config)

    self.ui:setup(config)
    self.initialized = true

    vim.api.nvim_create_user_command("MSDest", function()
        self:destroy()
    end, { desc = "Clean resources and un-initialize everything" })

    vim.api.nvim_create_autocmd({ "VimLeavePre"}, {
        buffer = self.ui.bufnr,
        group = MSGroup,
        once = true,
        callback = function() self:destroy() end,
    })

    -- assert(self:validate(), "End of setup")
end

return instance
