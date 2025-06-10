local winbuf = require('mark-scratch.winbuf')

local M = {}

---@enum ms.log.levels
M.log_levels = {
    DISABLED = 0,
    TRACE = 1,
    DEBUG = 2,
}

M.width = 100


---@param lines string[]
local function process_lines(lines)
    local s = table.concat(lines, '\n')

    -- split on newlines
    local res = {}
    for l in s:gmatch("(.-)\n") do
        table.insert(res, l)
    end

    -- captures a single line not containing any newlines
    table.insert(res, s:match('^([^\n]*)$'))
    -- captures the final line of a string with newlines, 
    table.insert(res, s:match('\n([^\n]*)$'))

    return res
end

---@param lvl ms.log.levels
---@param txt string[]
---@return string[]
local function add_debug_info(txt, lvl)

    local ret = {}
    if lvl == M.log_levels.TRACE then

        local dbg = debug.getinfo(3, 'nS')
        local fnname = dbg.name or "anonymous"
        local info = ("[%s.%s]"):format(dbg.short_src, fnname)

        local pad = math.max(M.width - #info, 0)
        local left = math.floor(pad / 2)
        local right = pad - left
        local title = string.rep('-', left) .. info .. string.rep('-', right)

        ret = vim.tbl_extend('force', ret, txt)
        table.insert(ret, 1, title)
    elseif lvl == M.log_levels.DEBUG then
        local dbg = debug.getinfo(3, 'nSl')

        local data = {}
        for k, v in pairs(dbg) do
            if k ~= "source" then
                table.insert(data, ("| %s: %s |"):format(k, v))
            end
        end

        ret = vim.tbl_deep_extend('keep', ret, txt)
        for i, v in ipairs(data) do
            table.insert(ret, i, v)
        end
        table.insert(ret, 1, string.rep('-', M.width))
    end


    return ret
end

---@class logger
---@field lines string[]
---@field level ms.log.levels
local logger = {}
logger.__index = logger

local function init()
    return setmetatable({
        lines = {},
        level = M.log_levels.TRACE
    }, logger)
end

function logger:log(...)
    if self.level == M.log_levels.DISABLED then
        return
    end

    local len = select('#', ...)

    local tmp = {}
    for i = 1, len do
        local pulled = select(i, ...)
        local item = type(pulled) == 'table' and vim.inspect(pulled) or tostring(pulled)

        table.insert(tmp, item)
    end

    tmp = add_debug_info(tmp, self.level)

    for _, v in ipairs(tmp) do
        table.insert(self.lines, v)
    end

end

function logger:print()
    vim.print(table.concat(self.lines, '\n'))
end

function logger:get_lines()
    return vim.deepcopy(self.lines, false)
end

function logger:show()
    local plines = process_lines(self.lines)
    local height = #plines > vim.o.lines and vim.o.lines or #plines + 3

    local hw = M.width/2
    local hh = height/2
    local row = math.floor(((vim.o.lines / 2) - hh) - 1)
    local col = math.floor((vim.o.columns / 2) - hw)

    local bufnr, winid = winbuf
        :new({ scratch = true })
        :bufopt('bufhidden', 'wipe')
        :win('float')
        :winsetconf({
            relative = 'editor',
            width = M.width,
            height = height,
            row = row,
            col = col,
        })
        :setlines(plines)
        :info()

    return bufnr, winid
end

function logger:clear()
    self.lines = {}
end

---@param lvl ms.log.levels
function logger:set_level(lvl)
    self.level = lvl
end

---@type logger
M.logg = init()

vim.api.nvim_create_user_command('LGClear', function() M.logg:clear() end, { desc = "clear logs"})


vim.api.nvim_create_user_command("LGShow", function() M.logg:show() end, { desc = "Display logs"})

return M
