---@param width? integer
---@param height? integer
local function make_floating_opts(width, height)
    width = width or 50
    height = height or 50

    ---@type vim.api.keyset.win_config
    return {
        relative = "editor",    -- ensures a float
        width = width,
        height = height,
        row = 1,
        col = 1,
        border = 'rounded',
        title = 'notes',
        title_pos = 'left',
        anchor = 'NW'
    }
end

---@param direction? 'above'|'below'|'left'|'right'
---@param vertical? boolean
local function make_split_opts(direction, vertical)

    direction = direction or 'right'
    vertical = vertical or true

    ---@type vim.api.keyset.win_config
    return {
        win = -1,               -- top-level split
        vertical = vertical,
        split = direction
    }
end

---@class obj
---@field bufnr integer
---@field winid integer
local obj = {}
obj.__index = obj


-- ---@param direction 'above'|'below'|'left'|'right'
-- ---@param vertical boolean
-- ---@return obj
-- function obj:split(direction, vertical)
--     local cfg = make_split_opts(direction, vertical)
--
--     self.winid = vim.api.nvim_open_win(self.bufnr, true, cfg)
--
--     return self
-- end

---@param cfg? vim.api.keyset.win_config
---@param existing? integer
---@return obj
function obj:split(cfg, existing)
    local wincfg = cfg and vim.tbl_deep_extend('force', make_split_opts(), cfg)
        or make_split_opts()

    if not vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.print("Invalid bufnr: " .. self.bufnr)
    end

    if existing then

        self.winid = existing
        if cfg then
            local existing_cfg = vim.api.nvim_win_get_config(existing)
            assert(existing_cfg.relative == cfg.relative, "Incompatable window and config")
            vim.api.nvim_win_set_config(self.winid, wincfg)
        end
    else
        self.winid = vim.api.nvim_open_win(self.bufnr, true, wincfg)
    end

    return self
end

---@param cfg? vim.api.keyset.win_config
---@param existing? integer
---@return obj
function obj:float(cfg, existing)
    local wincfg = cfg and vim.tbl_deep_extend('force', make_floating_opts(), cfg)
        or make_floating_opts()

    if not vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.print("Invalid bufnr: " .. self.bufnr)
    end

    if existing then
        self.winid = existing
        if cfg then
            local existing_cfg = vim.api.nvim_win_get_config(existing)
            assert(existing_cfg.relative == cfg.relative, "Incompatable window and config")
            vim.api.nvim_win_set_config(self.winid, wincfg)
        end
    else
        self.winid = vim.api.nvim_open_win(self.bufnr, true, wincfg)
    end

    return self
end

---@param name string | table
---@param val? any
---@return obj
function obj:winopt(name, val)
    if type(name) == "table" then
        for k, v in pairs(name) do
            vim.api.nvim_set_option_value(k, v, { scope = 'local', win = self.winid })
        end
    else
        vim.api.nvim_set_option_value(name, val, { scope = 'local', win = self.winid })
    end

    return self
end

---@param name string | table
---@param val? any
---@return obj
function obj:bufopt(name, val)
    if type(name) == "table" then
        for k, v in pairs(name) do
            vim.api.nvim_set_option_value(k, v, { scope = 'local', buf = self.bufnr })
        end
    else
        vim.api.nvim_set_option_value(name, val, { scope = 'local', buf = self.bufnr })
    end

    return self
end

---@return integer, integer
function obj:info()
    return self.bufnr, self.winid
end

---@return integer
function obj:bufinfo()
    return self.bufnr
end

---@return integer
function obj:wininfo()
    return self.winid
end

---@param cfg vim.api.keyset.win_config
---@return obj
function obj:winsetconf(cfg)
    local c = vim.tbl_deep_extend('force', vim.api.nvim_win_get_config(self.winid), cfg)
    vim.api.nvim_win_set_config(self.winid, c)
    return self
end

---@param lines string[]
---@param start? integer
---@param fin? integer
---@return obj
function obj:setlines(lines, start, fin)
    local row = start or 0
    local erow = fin or -1

    vim.api.nvim_buf_set_lines(self.bufnr, row, erow, false, lines)
    return self
end

---@class winbuf
---@field bufnr integer | nil
---@field winid integer | nil
local winbuf = {}
winbuf.__index = winbuf

---@class winbufOpts
---@field name? string
---@field bufnr? integer
---@field scratch? boolean

local count = 0
---@param opts winbufOpts
function winbuf:new(opts)
    count = count + 1

    local bufnr = opts.bufnr
        or (opts.scratch
            and vim.api.nvim_create_buf(true, true)
            or vim.api.nvim_create_buf(true, false))

    local name = opts.name or ('[winbuf | %d | %d]'):format(count, os.time())
    if not opts.bufnr then
        vim.api.nvim_buf_set_name(bufnr, name)
    end

    return setmetatable({ bufnr = bufnr, windnr = nil }, obj)
end

return winbuf
