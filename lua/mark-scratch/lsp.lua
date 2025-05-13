local Utils = require('mark-scratch.utils')

---@class msp
---@field client? vim.lsp.Client
---@field started boolean
local msp = {}
msp.__index = msp

---@class msp.validate
---@field started? boolean
---@field stopped? boolean

---@return vim.lsp.Client
function msp:get_client()
    return self.client
end

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

        local cli_is_stopped = self.client:is_stopped()
        local no_clients_attached = true
        for _, v in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
            if not v._is_stopping then no_clients_attached = false end
        end

        valid = not self.started
            and cli_is_stopped
            and no_clients_attached
    end

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
                error('invalid "stat" value: ' .. v[2] .. ', from inside "stop_lsp"')
            end
        end

        return ok
    end)

    if done then self.started = false else error('not done!') end

    return done
end


---@param config vim.lsp.ClientConfig
---@param bufnr? integer
function msp:start_lsp(bufnr, config)
    if self.started then return end

    bufnr = bufnr or 0
    assert(vim.api.nvim_buf_is_valid(bufnr))

    local lspnr = vim.lsp.start(config, { bufnr = bufnr })
    assert(lspnr, "Unable to start lsp!")

    vim.schedule(function()
        Utils.wait_until(function()
            return vim.lsp.buf_is_attached(bufnr, lspnr)
        end)
    end)

    self.client = vim.lsp.get_client_by_id(lspnr)

    self.started = true
end


return msp
