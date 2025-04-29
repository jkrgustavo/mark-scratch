local M = {}

---@class WaitOptions
---@field timeout? number
---@field interval? number

--- Check {condition} every {interval}ms until either {condition} is true or {timeout} is 
--- reached
---@param condition fun(): boolean
---@param opts? WaitOptions
---@return boolean
function M.wait_until(condition, opts)
  opts = opts or {}
  return vim.wait(
    opts.timeout  or 1000,   -- ms
    condition,
    opts.interval or 10,     -- ms
    false                    -- process UI events
  )
end

return M
