---@class stub
---@field restores {[string]: fun(nil): nil}
---@field originals {[string]: fun(any): any} 
---@field replacements {[string]: fun(any): any} 
---@field was_restored boolean
local stub = {}
stub.__index = stub

-- Lightweight stubs
local function with_stub(tbl, key, replacement)
    local orig = tbl[key]
    tbl[key] = replacement
    return function() tbl[key] = orig end
end

---@param tbl table
---@param key string
---@param replacement function
function stub:add(tbl, key, replacement)
    table.insert(self.restores, with_stub(tbl, key, replacement))
end

function stub:new()
    return setmetatable({
        restores = {},
        was_restored = false
    }, self)
end

function stub:restore()
    for _, rest in ipairs(self.restores) do rest() end
end

local M = {}

---@return stub
function M.new_stub()
    return stub:new()
end

M.winborder_presets = {
    none    = { "",  "",  "",  "",  "",  "",  "",  "" },
    single  = { "┌","─","┐","│","┘","─","└","│" },
    double  = { "╔","═","╗","║","╝","═","╚","║" },
    rounded = { "╭","─","╮","│","╯","─","╰","│" },
    solid   = { " ", " ", " ", " ", " ", " ", " ", " " },
    shadow  = {
        '',
        '',
        { ' ', 'FloatShadowThrough' },
        { ' ', 'FloatShadow' },
        { ' ', 'FloatShadow' },
        { ' ', 'FloatShadow' },
        { ' ', 'FloatShadowThrough' },
        ''
    }
}

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


---Check if one table is a subset of another
---@param subset table
---@param superset table
---@return boolean
function M.is_subset(subset, superset)
    if type(subset) ~= "table" or type(superset) ~= "table" then
        return subset == superset
    end

    for k, v in pairs(subset) do
        local w = superset[k]

        if w == nil then
            error(k .. " doesn't exist in superset. subset[k] = " .. v)
            return false
        end

        if type(v) == "table" and type(w) == "table" then
            if not M.tbl_subset(v, w) then return false end
        elseif v ~= w then return false end
    end

    return true
end

function M.wincfg_equal(expected, actual)
    -- neovim 'expands' some options after theyre set, this accounts for that
    if expected.border then
        expected.border = M.winborder_presets[expected.border]
    end

    if expected.title then
        actual.title = actual.title[1][1] == expected.title and expected.title or actual.title
    end

    return M.tbl_subset(expected, actual)
end

return M
