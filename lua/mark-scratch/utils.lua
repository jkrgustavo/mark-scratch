local M = {}

---@class WaitOptions
---@field timeout integer
---@field interval integer

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

--- Call 'tostring' on every argument passed
--- Return unpacked
function M.tostrings(...)
    local len = select('#', ...)
    local args = {...}

    local strings = {}
    for i = 1, len do
        strings[i] = tostring(args[i])
    end

    if not table.unpack then
        ---@diagnostic disable-next-line: deprecated
        table.unpack = unpack
    end

    return table.unpack(strings)
end

---@param str string
---@param char string
---@return string[]
function M.str_split(str, char)

    local res = {}

    for l in str:gmatch("([^" .. char .. "]+)") do
        table.insert(res, l)
    end

    return res
end


---@param str string
---@return string[]
function M.str_lines(str)
    if not str then return {} end

    -- split on newlines
    local res = {}
    for l in str:gmatch("(.-)\n") do
        table.insert(res, l)
    end

    -- captures a single line not containing any newlines
    table.insert(res, str:match('^([^\n]*)$'))
    -- captures the final line of a string with newlines, 
    table.insert(res, str:match('\n([^\n]*)$'))

    return res
end

return M
