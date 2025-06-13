local Utils = require('mark-scratch.utils')
local Logg = require('mark-scratch.logger').logg

---@param bufnr integer
---@return vim.lsp.ClientConfig
local function default_cli_config(bufnr)
    ---@type vim.lsp.ClientConfig
    return {
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
end

---@class msp
---@field client? vim.lsp.Client
---@field started boolean
local msp = {}
msp.__index = msp

---@class msp.validate
---@field started? boolean
---@field stopped? boolean

---@param opt msp.validate
---@return boolean
function msp:validate(bufnr, opt)
    local valid = true

    if opt.started then
        valid = self.started
            and self.client
            and vim.lsp.buf_is_attached(bufnr, self.client.id)
            and not self.client:is_stopped()
            or false
    elseif opt.stopped then
        local cli_is_stopped
        if not self.client then
            cli_is_stopped = true
        else
            cli_is_stopped = self.client:is_stopped()
        end

        local no_clients_attached = true
        for _, v in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
            if not v._is_stopping then no_clients_attached = false end
        end

        valid = not self.started
            and cli_is_stopped
            and no_clients_attached
    end

    if not valid then Logg:log("Failed to validate: ", self) end

    return valid
end

---@param bufnr integer
---@return boolean
function msp:stop_lsp(bufnr)
    if self.client then self.client:stop(false) end

    local attached_clients = vim.lsp.get_clients({ bufnr = bufnr })
    -- no clients are attached to the buffer, done
    if #attached_clients == 0 then
        self.started = false
        return true
    end

    local stat = {}
    for _, v in ipairs(attached_clients) do
        -- if the lsp is attached to other buffers, detach it from this one
        if #v.attached_buffers > 1 then
            vim.lsp.buf_detach_client(bufnr, v.id)
            table.insert(stat, { v, 'detached' })
        else -- otherwise just stop the lsp
            v:stop(false)
            table.insert(stat, { v, 'stopped' })
        end
    end

    local done =  Utils.wait_until(function()
        local ok = true
        for _, v in ipairs(stat) do
            if not ok then break end

            if v[2] == 'detached' then -- make sure the lsp detached
                ok = not vim.lsp.buf_is_attached(bufnr, v.id)
            elseif v[2] == 'stopped' then -- make sure it stopped
                ok = v[1]:is_stopped()
            else
                Logg:log("Invalid 'stat': " .. v[2] .. ", shouldn't be possible")
            end
        end

        return ok
    end)

    if done then
        self.started = false
        Logg:log("Finished shutting down lsp")
    else
        Logg:log("'done' was false")
    end

    return done
end


---@param bufnr integer
---@param config? vim.lsp.ClientConfig
function msp:start_lsp(bufnr, config)
    if self.started then return end

    config = config
        and vim.tbl_deep_extend('force', default_cli_config(bufnr), config)
        or default_cli_config(bufnr)

    if not vim.api.nvim_buf_is_valid(bufnr) then
        Logg:log("Invalid bufnr: ", bufnr)
    end

    local lspnr = vim.lsp.start(config, { bufnr = bufnr })
    if not lspnr then
        Logg:log("Couldn't start the lsp", self)
        error("Unable to start lsp server")
    end

    vim.schedule(function()
        Utils.wait_until(function()
            return vim.lsp.buf_is_attached(bufnr, lspnr)
        end)
    end)

    self.client = vim.lsp.get_client_by_id(lspnr)

    ---@diagnostic disable-next-line: param-type-mismatch
    vim.treesitter.query.set('markdown', 'highlights', nil) -- nil resets the explicit query set by lspsaga
    vim.treesitter.language.register('markdown', 'scratchmarkdown')
    vim.treesitter.language.add('markdown')
    vim.treesitter.start(bufnr, 'markdown')

    self.started = true

    Logg:log("Lsp started", config)
end

---@return msp
local function new()
    Logg:log("Creating new msp")

    return setmetatable({
        client = nil,
        started = false,
    }, msp)
end

local instance = new()

return instance
