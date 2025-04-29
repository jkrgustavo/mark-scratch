local M = {}

--- Check {condition} every {interval}ms until either {condition} is true or {timeout} is 
--- reached
---@param condition fun(): boolean
---@param timeout? integer
---@param interval? integer
---@return boolean
function M.wait_until(condition, timeout, interval)
    timeout = 1000 or timeout -- default 1 second
    interval = 10 or interval -- default 10ms

    local met = false
    local elapsed = 0
    while not met and elapsed < timeout do
        met = condition()
        vim.wait(interval)
        elapsed = elapsed + interval
    end

    return met
end

return M
