local Utils = require("mark-scratch.utils")
local MSGroup = require("mark-scratch.augroup")
local Logg = require('mark-scratch.logger').logg
local Config = require('mark-scratch.config')
local Ui = require('mark-scratch.ui')
local File = require('mark-scratch.file')

---@class Scratch
---@field initialized boolean
---@field config ms.config
---@field ui Ui
---@field file ms.file
local Scratch = {}
Scratch.__index = Scratch

local function new()
    local config = Config.default_config

    return setmetatable({
        initialized = false,
        config = config,
        ui = Ui,
        file = File
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


    Logg:log("Destroying scratch")

    pcall(vim.api.nvim_del_augroup_by_id, MSGroup)

    self.ui:shutdown()
    self.file:shutdown()

    local augroup_clean = Utils.wait_until(function()
        return not pcall(vim.api.nvim_get_autocmds, { group = MSGroup })
    end)

    assert(augroup_clean, "Unable to delete augroup")

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
        Logg:log("attempt to re-initialize")
        return
    end

    self.config = vim.tbl_deep_extend('force', self.config, config)

    self.file:setup(config)
    self.ui:setup(config)
    self.initialized = true

    -- assert(self:validate(), "End of setup")
end

return instance
