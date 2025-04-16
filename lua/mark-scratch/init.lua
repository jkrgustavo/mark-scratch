---@class Scratch
---@field bufnr integer
---@field initialized boolean
---@field cmd_group integer
---@field lsp_client integer
local Scratch = {}

Scratch.__index = Scratch

function Scratch.new()
    return setmetatable({
        bufnr = -1,
        cmd_group = -1,
        lsp_client = -1,
        initialized = false
    }, Scratch)
end

---@return boolean
function Scratch:validate()

    if not self.initialized then
        vim.notify("Uninitialized", vim.log.levels.WARN)
        return false
    end

    for k, v in pairs(self) do
        if not v or v == -1 then
            vim.notify("[" .. k .. "] is uninitialized", vim.log.levels.WARN)
            return false
        end
    end

    if not vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.notify("Invalid buffer", vim.log.levels.WARN)
        return false
    end

    if not vim.lsp.buf_is_attached(self.bufnr, self.lsp_client) then
        vim.notify("Lsp isn't attached to buffer", vim.log.levels.WARN)
        return false
    end

    if #vim.api.nvim_get_autocmds({ group = self.cmd_group }) == 0 then
        vim.notify("No autocommands are setup", vim.log.levels.WARN)
        return false
    end

    return true
end

---@param bufnr integer
---@param group integer
local function attach_tree_lsp(bufnr, group)

    if not vim.api.nvim_buf_is_valid(bufnr) or group == -1 then
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

    local clinr = vim.lsp.start(client_config, { bufnr = bufnr })
    if not clinr then
        error("Unable to get marksman started for the scratch buffer! Called 'vim.lsp.start'")
        return -1
    end
    vim.lsp.buf_attach_client(bufnr, clinr)

    vim.treesitter.language.add('markdown')
    vim.treesitter.start(bufnr, 'markdown')

    vim.api.nvim_create_autocmd({ "VimLeavePre"}, {
        buffer = bufnr,
        group = group,
        once = true,
        callback = function()
            vim.notify("Stopping scratch-marksman client", vim.log.levels.INFO)
            vim.lsp.stop_client(clinr, false)
        end
    })

    return clinr
end

local function create_buffer()
    local bufnr = vim.api.nvim_create_buf(true, false)

    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide" -- NOTE: Change this to 'hide' after testing 
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "markdown"

    vim.api.nvim_buf_set_name(bufnr, "[Note" .. os.time() .. "].md")

    return bufnr
end

function Scratch:open_window()
    assert(self:validate(), "Opening window")

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
        group = self.cmd_group,
        callback = function()
            if vim.api.nvim_buf_is_valid(self.bufnr) then
                vim.api.nvim_win_close(windnr, true)
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

    self.cmd_group = vim.api.nvim_create_augroup("mark-scratch", { clear = false })
    self.bufnr = create_buffer()
    self.lsp_client = attach_tree_lsp(self.bufnr, self.cmd_group)
    self.initialized = true

    vim.api.nvim_create_user_command("DL", function()
        if vim.api.nvim_buf_is_valid(self.bufnr) then
            vim.defer_fn(function()
                vim.bo[self.bufnr].buflisted = false
                vim.api.nvim_buf_delete(self.bufnr, { unload = true })
            end, 10)
        end
    end, { desc = "Destroy a buffer" })

    vim.api.nvim_create_autocmd({ "BufHidden" }, {
        buffer = self.bufnr,
        once = true,
        group = self.cmd_group,
        callback = function()
            if vim.api.nvim_buf_is_valid(self.bufnr) then
                vim.defer_fn(function()
                    vim.lsp.stop_client(self.lsp_client, false)
                    vim.api.nvim_buf_delete(self.bufnr, { force = true })
                    if not vim.lsp.client_is_stopped(self.lsp_client) then
                        vim.lsp.stop_client(self.lsp_client, true)
                    end
                end, 10)
            end
        end
    })

    assert(self:validate(), "End of setup")
end

return Scratch.new()
