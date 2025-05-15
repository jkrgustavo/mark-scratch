package.loaded['mark-scratch.winbuf'] = nil
local winbuf = require('mark-scratch.winbuf')

---@class logger
---@field lines string[]
local logger = {}
logger.__index = logger

---@param lines string[]
local function process_lines(lines)
    local s = table.concat(lines, '\n')

    -- split on newlines
    local res = {}
    for l in s:gmatch("(.-)\n") do
        table.insert(res, l)
    end

    -- first captures a single line not containing any newlines
    -- second captures the final line of a string with newlines, 
    table.insert(res, s:match('^([^\n]*)$'))
    table.insert(res, s:match('\n([^\n]*)$'))

    return res
end

function logger:log(...)
    local len = select('#', ...)
    for i = 1, len do
        local pulled = select(i, ...)
        local item = type(pulled) == 'table' and vim.inspect(pulled) or tostring(pulled)

        table.insert(self.lines, item)
    end

end

function logger:print()
    vim.print(table.concat(self.lines, '\n'))
end

function logger:show()
    local plines = process_lines(self.lines)
    local width = 50
    local height = #plines > 75 and 75 or #plines

    local hw = width/2
    local hh = height/2
    local row = math.floor(((vim.o.lines / 2) - hh) - 1)
    local col = math.floor((vim.o.columns / 2) - hw)

    local bufnr, winid = winbuf:new({ scratch = true })
        :bufopt('bufhidden', 'wipe')
        :float({
            relative = 'editor',
            width = width,
            height = height,
            row = row,
            col = col,
        })
        :winopt('wrap', true)
        :setlines(plines)
        :info()

    return bufnr, winid
end

function logger:_debug()


end

function logger:clear()
    self.lines = {}
end

local function init()
    return setmetatable({
        lines = {},
    }, logger)
end

---@type logger
local logg = init()

return logg
