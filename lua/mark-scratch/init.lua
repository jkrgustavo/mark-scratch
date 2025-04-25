package.loaded["mark-scratch.window"] = nil

local Win = require("mark-scratch.window")

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
function Scratch:validate()

    for k, v in pairs(self) do
        if (not v or v == -1) and k ~= "windnr" then
            vim.notify("[" .. k .. "] is uninitialized", vim.log.levels.WARN)
            return false
        end
    end

    if not vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.notify("Invalid buffer", vim.log.levels.WARN)
        return false
    end

    if not vim.lsp.client_is_stopped(self.lspnr) and
        not vim.lsp.buf_is_attached(self.bufnr, self.lspnr)
    then
        vim.notify("Lsp isn't attached to buffer", vim.log.levels.WARN)
        return false
    end

    if #vim.api.nvim_get_autocmds({ group = self.augroup }) == 0 and not self.initialized then
        vim.notify("No autocommands are setup", vim.log.levels.WARN)
        return false
    end

    if self.windnr and not vim.api.nvim_win_is_valid(self.windnr) then
        vim.notify("Invalid windnr", vim.log.levels.WARN)
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

--    ---@type vim.lsp.ClientConfig
    local client_config = {
        name = "scratch-marksman",
        cmd = { 'marksman', 'server' },
        cmd_cwd = vim.fn.getcwd(),
        workspace_folders = nil,
        root_dir = nil,
        settings = {
			filetypes = { "markdown" },
        }
    }

    local clinr = vim.lsp.start(client_config, { bufnr = bufnr })
    if not clinr then
        error("Unable to get marksman started for the scratch buffer! Called 'vim.lsp.start'")
        return -1
    end
    vim.lsp.buf_attach_client(bufnr, clinr)

---@diagnostic disable-next-line: param-type-mismatch
    vim.treesitter.query.set('markdown', 'highlights', nil) -- nil resets the explicit query
    vim.treesitter.language.add('markdown')
    vim.treesitter.start(bufnr, 'markdown')

    return clinr
end

local function create_buffer()
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, "[Note" .. os.time() .. "].md")

    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "markdown"

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
        callback = function() scratch.windnr = nil end
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
    assert(self:validate(), "Opening window")

    local width = 50
    local height = 50

    self.windnr = vim.api.nvim_open_win(self.bufnr, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = 'Notes'
    })

end

function Scratch:close_window()
    if not self.windnr then
        return
    elseif not vim.api.nvim_win_is_valid(self.windnr) then
        self.windnr = nil
        return
    end

    vim.api.nvim_win_close(self.windnr, false)

    vim.defer_fn(function()
        if self.windnr and vim.api.nvim_win_is_valid(self.windnr) then
            vim.notify("Attempt to close window failed, forcing...")
            vim.api.nvim_win_close(self.windnr, true)
        end

        self.windnr = nil
    end, 10)

end

function Scratch:clear()
    assert(self:validate(), "in 'clear'")

    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, {})
end

function Scratch:destroy()

    if self.windnr then
        vim.api.nvim_win_close(self.windnr, true)
    end

    vim.treesitter.stop(self.bufnr)

    if not vim.lsp.client_is_stopped(self.lspnr) then
        vim.lsp.stop_client(self.lspnr, true)
    end


    vim.api.nvim_clear_autocmds({ group = self.augroup })
    vim.api.nvim_del_augroup_by_id(self.augroup)

    vim.defer_fn(function()
        vim.bo[self.bufnr].buflisted = false
        vim.api.nvim_buf_delete(self.bufnr, { force = true })

        self.initialized = false
    end, 10)

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
    return Win
end

return Scratch.new()

-- TODO: Keybindings
-- TODO: Actual ui
