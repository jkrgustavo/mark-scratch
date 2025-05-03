package.loaded["mark-scratch.winbuf"] = nil
package.loaded["mark-scratch.utils"] = nil

local Winbuf = require("mark-scratch.winbuf")
local Utils = require("mark-scratch.utils")

---@class Scratch
---@field bufnr integer
---@field initialized boolean
---@field augroup integer
---@field lspnr integer
---@field windnr integer | nil
local Scratch = {}

Scratch.__index = Scratch

function Scratch.new()
    return setmetatable({
        bufnr = -1,
        augroup = -1,
        lspnr = -1,
        windnr = nil,
        initialized = false,
    }, Scratch)
end

---@return boolean
---@param silent? boolean
function Scratch:validate(silent)

    if not self.initialized then
        if not silent then vim.notify("Uninitialized", vim.log.levels.WARN) end
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

    if not vim.lsp.client_is_stopped(self.lspnr) and
        not vim.lsp.buf_is_attached(self.bufnr, self.lspnr)
    then
        if not silent then error("Lsp isn't attached to buffer", 2) end
        return false
    end

    if #vim.api.nvim_get_autocmds({ group = self.augroup }) == 0 and not self.initialized then
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
        error("Bufnr is invalid or group == -1, in 'attach_tree_lsp'")
        return -1
    end

    ---@type vim.lsp.ClientConfig
    local client_config = {
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
    }
    local clinr = vim.lsp.start(client_config, { bufnr = bufnr })

    assert(clinr, "Unable to get marksman started for the scratch buffer! Called 'vim.lsp.start'")

    vim.lsp.buf_attach_client(bufnr, clinr)

    ---@diagnostic disable-next-line: param-type-mismatch
    vim.treesitter.query.set('markdown', 'highlights', nil) -- nil resets the explicit query
    vim.treesitter.language.register('markdown', 'scratchmarkdown')
    vim.treesitter.language.add('markdown')
    vim.treesitter.start(bufnr, 'markdown')

    return clinr
end

local count = 0

local function create_buffer()
    count = count + 1
    local name = "[Note" .. "|" .. count .. "|" .. os.time() .. "].md"

    local bufnr = Winbuf
        :new({ name = name })
        :bufopt({
            ['buftype'] = 'nofile',
            ['bufhidden'] = 'hide',
            ['swapfile'] = false,
            ['filetype'] = 'scratchmarkdown'
        })
        :bufinfo()

    return bufnr
end

---@param scratch Scratch
local function setup_auto_commands(scratch)
    local augroup = vim.api.nvim_create_augroup("mark-scratch", { clear = true })

    vim.api.nvim_create_autocmd({ "VimLeavePre"}, {
        buffer = scratch.bufnr,
        group = augroup,
        once = true,
        callback = function() scratch:destroy() end
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
        buffer = scratch.bufnr,
        once = false,
        group = augroup,
        callback = function() scratch:close_window() end
    })

    vim.api.nvim_create_autocmd({ "BufHidden" }, {
        buffer = scratch.bufnr,
        once = true,
        group = augroup,
        callback = function() scratch:close_window() end
    })

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        buffer = scratch.bufnr,
        once = false,
        group = augroup,
        callback = function()
            if scratch.windnr and not vim.api.nvim_win_is_valid(scratch.windnr) then
                scratch.windnr = nil
            end
        end
    })

    return augroup
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
end

function Scratch:close_window()
    if not self.windnr or not vim.api.nvim_win_is_valid(self.windnr) then
        self.windnr = nil
        return
    end

    local winid = self.windnr or -1
    local ok, err = pcall(vim.api.nvim_win_close, winid, false)
    if not ok then
        vim.print('close_window(): ' .. err)
        return
    end

    vim.schedule(function()
        if not vim.api.nvim_win_is_valid(winid) then
            self.windnr = nil
        end
    end)
end

function Scratch:clear()
    assert(self:validate(), "in 'clear'")

    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, {})
end

---@param bufnr integer
---@param lspnr integer
local function cleanup_lsp(bufnr, lspnr)
    local bufs = vim.api.nvim_list_bufs()
    local lsp_is_used_elsewere = false

    if vim.lsp.buf_is_attached(bufnr, lspnr) then
        vim.lsp.buf_detach_client(bufnr, lspnr)
    end

    for _, b in ipairs(bufs) do
        if b ~= bufnr and vim.lsp.buf_is_attached(b, lspnr) then
            lsp_is_used_elsewere = true
            break
        end
    end


    if not lsp_is_used_elsewere then
        vim.lsp.stop_client(lspnr, false)
        if not Utils.wait_until(function() return vim.lsp.client_is_stopped(lspnr) end) then
            error("Unable to stop client!")
            return
        end
    end

end


---@param bufnr integer
local function cleanup_portals(bufnr)
    local buf_portals = vim.fn.win_findbuf(bufnr)
    if #buf_portals > 0 then
        for _, p in ipairs(buf_portals) do
            local ok, err = pcall(vim.api.nvim_win_close, p, true)
            if not ok then
                vim.print("Not ok while cleaning up portals:" .. vim.inspect(err))
            end
        end
    end
end


function Scratch:destroy()

    pcall(vim.api.nvim_clear_autocmds, { group = self.augroup })
    pcall(vim.api.nvim_del_augroup_by_id, self.augroup)

    cleanup_portals(self.bufnr)
    self.windnr = nil

    vim.treesitter.stop(self.bufnr)

    cleanup_lsp(self.bufnr, self.lspnr)
    for _, v in ipairs(vim.lsp.get_clients({ bufnr = self.bufnr })) do
        cleanup_lsp(self.bufnr, v.id)
    end

    local clean = Utils.wait_until(function()
        local open_portals = #vim.fn.win_findbuf(self.bufnr) ~= 0
        local lsp_attached = vim.lsp.buf_is_attached(self.bufnr, self.lspnr)
        local aug_exists = pcall(vim.api.nvim_get_autocmds, { group = self.augroup })

        return not open_portals and not lsp_attached and not aug_exists
    end)


    if clean then
        if vim.api.nvim_buf_is_valid(self.bufnr) then
            vim.bo[self.bufnr].buflisted = false
            vim.api.nvim_buf_delete(self.bufnr, { force = true })
        end

        self.lspnr = -1
        self.bufnr = -1
        self.augroup = -1
        self.initialized = false
    else
        error("unable to delete buffer: " .. self.bufnr)
    end


end

function Scratch:setup()

    if self.initialized then
        vim.notify("Can't double initialize mark-scratch", vim.log.levels.INFO)
        return
    end

    self.bufnr = create_buffer()
    self.lspnr = attach_tree_lsp(self.bufnr)
    self.augroup = setup_auto_commands(self)
    self.initialized = true

    setup_user_commands(self)

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

    - Use a temp file instead?

--]]
