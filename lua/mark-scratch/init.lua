local Winbuf = require("mark-scratch.winbuf")
local Utils = require("mark-scratch.utils")
local MSGroup = require("mark-scratch.augroup")
local Msp = require('mark-scratch.lsp')
local Logg = require('mark-scratch.logger')
local Config = require('mark-scratch.config')

---@class Scratch
---@field bufnr integer
---@field initialized boolean
---@field windnr integer | nil
---@field config ms.config
local Scratch = {}

Scratch.__index = Scratch

function Scratch.new()
    return setmetatable({
        bufnr = -1,
        windnr = nil,
        initialized = false,
        config = Config.default_config
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

    if not vim.api.nvim_buf_is_valid(self.bufnr) then
        if not silent then error("Invalid buffer", 2) end
        return false
    end

    if not Msp:validate(self.bufnr, { started = true }) then
        if not silent then error("Lsp isn't attached to buffer", 2) end
        return false
    end

    if #vim.api.nvim_get_autocmds({ group = MSGroup }) == 0 and not self.initialized then
        if not silent then error("No autocommands are setup", 2) end
        return false
    end

    if self.windnr and not vim.api.nvim_win_is_valid(self.windnr) then
        if not silent then error("Invalid windnr", 2) end
        return false
    end

    return true
end

---@param bufnr integer
local function attach_tree_lsp(bufnr)

    if not vim.api.nvim_buf_is_valid(bufnr) then
        Logg:log("[scratch.attachtreelsp] " .. "Invalid bufnr")
        return -1
    end

    Msp:start_lsp(bufnr, {
        name = "scratch-marksman",
        cmd = { 'marksman', 'server' },
        workspace_folders = nil,
        root_dir = vim.fn.getcwd(),
		filetypes = { "scratchmarkdown" },
        on_attach = function (client)
            if client.server_capabilities.semanticTokensProvider then
                vim.lsp.semantic_tokens.start(bufnr, client.id)
            end
        end
    })

    ---@diagnostic disable-next-line: param-type-mismatch
    vim.treesitter.query.set('markdown', 'highlights', nil) -- nil resets the explicit query from lspsaga
    vim.treesitter.language.register('markdown', 'scratchmarkdown')
    vim.treesitter.language.add('markdown')
    vim.treesitter.start(bufnr, 'markdown')
end

local count = 0

local function create_buffer()
    count = count + 1
    local name = "[Note" .. "|" .. count .. "|" .. os.time() .. "|" .. math.random(1000) .. "].md"

    -- TODO: Use scratch option when creating buffer
    local bufnr = Winbuf
        :new({ name = name })
        :bufopt({
            ['buftype'] = 'nofile',
            ['bufhidden'] = 'hide',
            ['swapfile'] = false,
            ['filetype'] = 'scratchmarkdown'
        })
        :bufinfo()

    Logg:log("[scratch.createbuffer] "
        .. ("created buffer %d with name: '%s'"):format(bufnr, name))

    return bufnr
end

---@param scratch Scratch
local function setup_auto_commands(scratch)

    vim.api.nvim_create_autocmd({ "VimLeavePre"}, {
        buffer = scratch.bufnr,
        group = MSGroup,
        once = true,
        callback = function() scratch:destroy() end
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
        buffer = scratch.bufnr,
        once = false,
        group = MSGroup,
        callback = function() scratch:close_window() end
    })

    vim.api.nvim_create_autocmd({ "BufHidden" }, {
        buffer = scratch.bufnr,
        once = true,
        group = MSGroup,
        callback = function() scratch:close_window() end
    })

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        buffer = scratch.bufnr,
        once = false,
        group = MSGroup,
        callback = function()
            if scratch.windnr and not vim.api.nvim_win_is_valid(scratch.windnr) then
                scratch.windnr = nil
            end
        end
    })
end

---@param scratch Scratch
local function setup_user_commands(scratch)

    vim.api.nvim_create_user_command("MSDest", function()
        scratch:destroy()
    end, { desc = "Destroy a buffer" })

    vim.api.nvim_create_user_command("MSOpen", function()
        scratch:open_window()
    end, { desc = "Open scratch window"})

    vim.api.nvim_create_user_command("MSClear", function()
        scratch:clear()
    end, { desc = "Clear scratch window"})

    vim.api.nvim_create_user_command("MSClose", function()
        scratch:close_window()
    end, { desc = "Close scratch window"})
end

function Scratch:open_window()
    assert(self:validate(), "Failed to validate while opening window")

    self.windnr = Winbuf
        :new({ bufnr = self.bufnr })
        :float()
        :winopt({
            ['wrap'] = true,
            ['conceallevel'] = 2
        })
        :wininfo()

    Logg:log("[scratch.openwin] " .. "Opened scratch window")
end

function Scratch:close_window()
    if not self.windnr or not vim.api.nvim_win_is_valid(self.windnr) then
        Logg:log("[scratch.closewindow] " .. "window wasn't valid")
        self.windnr = nil
        return
    end

    local winid = self.windnr or -1
    local ok, err = pcall(vim.api.nvim_win_close, winid, false)
    if not ok then
        Logg:log("[scratch.closewindow] " .. "Error closing window: " .. err)
        return
    end

    vim.schedule(function()
        if not vim.api.nvim_win_is_valid(winid) then
            Logg:log("[scratch.closewindow] " .. "Closing window")
            self.windnr = nil
        end
    end)
end

function Scratch:clear()
    assert(self:validate(), "in 'clear'")

    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, {})
end


---@param bufnr integer
local function cleanup_portals(bufnr)
    local buf_portals = vim.fn.win_findbuf(bufnr)
    if #buf_portals > 0 then
        for _, p in ipairs(buf_portals) do
            local ok, err = pcall(vim.api.nvim_win_close, p, true)
            if not ok then
                Logg:log("[scratch.cleanupportals] " .. "Error while calling win_close: " .. err)
            end
        end
    end
end

function Scratch:destroy()
    if not self.initialized then
        Logg:log('[scratch.destroy] ', "Tried to destroy while 'self.initialized' was false")
        return
    end

    Logg:log("[scratch.destroy] " .. "Destroying scratch")

    pcall(vim.api.nvim_clear_autocmds, { group = MSGroup })
    pcall(vim.api.nvim_del_augroup_by_id, MSGroup)

    cleanup_portals(self.bufnr)
    self.windnr = nil

    vim.treesitter.stop(self.bufnr)

    Msp:stop_lsp(self.bufnr)

    local clean = Utils.wait_until(function()
        local no_open_portals = #vim.fn.win_findbuf(self.bufnr) == 0
        local lsp_not_attached = Msp:validate(self.bufnr, { stopped = true })
        local aug_is_ok = pcall(vim.api.nvim_get_autocmds, { group = MSGroup })

        if not no_open_portals and not lsp_not_attached and aug_is_ok then
            Logg:log("[scratch.destroy] while waiting" .. ("windows: %s | lsp: %s | aug: %s")
                 :format(Utils.tostrings(no_open_portals, lsp_not_attached, not aug_is_ok)))
        end

        return no_open_portals and lsp_not_attached and not aug_is_ok
    end)

    if not clean then
        Logg:log("[scratch.destroy] 'clean' was false", self)
        error("unable to delete buffer: " .. self.bufnr)
    end

    if vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.bo[self.bufnr].buflisted = false
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    assert(Utils.wait_until(function()
        return not vim.api.nvim_buf_is_valid(self.bufnr)
    end))

    Logg:log("[scratch.destroy] " .. "Destroyed")
    self.lspnr = -1
    self.initialized = false
    self.bufnr = -1
end


---@param config? ms.config.partial
function Scratch:setup(config)

    if self.initialized then
        Logg:log("[scratch.setup] attempt to re-initialize", self)
        return
    end

    self.config = vim.tbl_deep_extend('force', self.config, config)

    self.bufnr = create_buffer()
    self.lspnr = attach_tree_lsp(self.bufnr)
    setup_auto_commands(self)
    setup_user_commands(self)
    self.initialized = true


    assert(self:validate(), "End of setup")
end

function Scratch:test()
    return Winbuf
end

return Scratch.new()

--[[ TODO:

    - config
    - keybindings
    - actual ui
    - better error handling
    - save to a file

--]]

