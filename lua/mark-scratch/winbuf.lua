-- TODO: 
-- Error handling
-- Better configuration

---@param width? integer
---@param height? integer
local function make_floating_opts(width, height)
    width = width or 50
    height = height or 50

    ---@type vim.api.keyset.win_config
    return {
        relative = "editor",
        width = width,
        height = height,
        row = -5,
        col = -5,
        border = 'rounded',
        title = 'notes',
        title_pos = 'left',
        anchor = 'SE'
    }
end

---@param direction 'above'|'below'|'left'|'right'
---@param vertical boolean
local function make_split_opts(direction, vertical)

    ---@type vim.api.keyset.win_config
    return {
        win = -1,
        vertical = vertical,
        split = direction
    }
end

---@class obj
---@field bufnr integer
---@field winid integer
local obj = {}
obj.__index = obj


---@param direction 'above'|'below'|'left'|'right'
---@param vertical boolean
---@return obj
function obj:split(direction, vertical)
    local cfg = make_split_opts(direction, vertical)

    self.winid = vim.api.nvim_open_win(self.bufnr, true, cfg)

    return self
end

---@param cfg? vim.api.keyset.win_config
---@return obj
function obj:float(cfg)
    local wincfg = cfg and vim.tbl_deep_extend('force', make_floating_opts(), cfg)
        or make_floating_opts()

    if not vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.print("Invalid bufnr: " .. self.bufnr)
    end
    self.winid = vim.api.nvim_open_win(self.bufnr, true, wincfg)

    return self
end

---@param name string | table
---@param val? any
---@return obj
function obj:winopt(name, val)
    if type(name) == "table" then
        for k, v in pairs(name) do
            vim.wo[self.winid][0][k] = v
            -- vim.api.nvim_set_option_value(k, v, { scope = 'local', win = self.winid })
        end
    else
        vim.wo[self.winid][0][name] = val
        -- vim.api.nvim_set_option_value(name, val, { scope = 'local', win = self.winid })
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

---@class winbuf
---@field bufnr integer | nil
---@field winid integer | nil
local winbuf = {}

---@class winbufOpts
---@field name? string
---@field bufnr? integer

local count = 0
---@param opts winbufOpts
function winbuf:new(opts)
    count = count + 1

    local name = opts.name or ('[winbuf | %d | %d]'):format(count, os.time())
    self.bufnr = opts.bufnr or vim.api.nvim_create_buf(true, false)

    if not opts.bufnr then
        vim.api.nvim_buf_set_name(self.bufnr, name)
    end

    return setmetatable(winbuf, obj)
end

return winbuf
