---@class Scratch
---@field bufnr integer
---@field initialized boolean
---@field scratch_group integer
---@field lsp_client integer
local Scratch = {}

Scratch.__index = Scratch

function Scratch.new()
    return setmetatable({
        bufnr = -1,
        scratch_group = -1,
        lsp_client = -1,
        initialized = false
    }, Scratch)
end

function Scratch:validate()
    return self.initialized and vim.api.nvim_buf_is_valid(self.bufnr)
end

---@param bufnr integer
local function attach_tree_lsp(bufnr)

    if not vim.api.nvim_buf_is_valid(bufnr) then
        error("Invalid Scratch from within 'start_tree_lsp'")
        return -1
    end

    ---@type vim.lsp.ClientConfig
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

    local clinr = vim.lsp.start(client_config, {
        bufnr = bufnr,
    })
    if not clinr then
        error("Unable to get marksman started for the scratch buffer! Called 'vim.lsp.start'")
        return -1
    end
    vim.lsp.buf_attach_client(bufnr, clinr)

    vim.treesitter.language.add('markdown')
    vim.treesitter.start(bufnr, 'markdown')

    return clinr
end

local function create_buffer()
    local bufnr = vim.api.nvim_create_buf(true, false)
    local bufname = "[Note" .. os.time() .. "].md"

    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide" -- NOTE: Change this to 'hide' after testing 
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "markdown"

    vim.api.nvim_buf_set_name(bufnr, bufname)

    return bufnr
end

function Scratch:open_window()

    if not self:validate() then
        error("Attempt to open invalid Scratch!!!")
        return
    end

    local width = 50
    local height = 50

    local windnr = vim.api.nvim_open_win(self.bufnr, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = 'Notes'
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
        buffer = self.bufnr,
        once = true,
        group = self.scratch_group,
        callback = function()
            if vim.api.nvim_buf_is_valid(self.bufnr) then
                vim.api.nvim_win_close(windnr, true)
            end
        end

    })

    vim.api.nvim_create_autocmd({ "BufHidden" }, {
        buffer = self.bufnr,
        once = true,
        group = self.scratch_group,
        callback = function()
            if vim.api.nvim_buf_is_valid(self.bufnr) then
                vim.defer_fn(function()
                    vim.print(self.lsp_client)
                    vim.lsp.stop_client(self.lsp_client, true)
                    vim.api.nvim_buf_delete(self.bufnr, { force = true })
                end, 10)
            end
        end
    })

    return windnr

end

function Scratch:setup()

    if self.initialized then
        vim.notify("Can't double initialize mark-scratch", vim.log.levels.INFO)
        return
    end

    self.scratch_group = vim.api.nvim_create_augroup("mark-scratch", { clear = false })
    self.bufnr = create_buffer()
    self.lsp_client = attach_tree_lsp(self.bufnr)
    self.initialized = true

    vim.api.nvim_create_user_command("DL", function()
        if self:validate() then
            vim.defer_fn(function()
                vim.bo[self.bufnr].buflisted = false
                vim.api.nvim_buf_delete(self.bufnr, { unload = true })
            end, 10)
        end
    end, { desc = "Destroy a buffer" })

    if not self:validate() then
        error("'self.validate()' failed at the end of setup!")
    end
end

return Scratch.new()
