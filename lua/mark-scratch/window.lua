local count = 0

---@class win
---@field bufnr integer
---@field winid integer
local win = {}

local function winconfig_default()
    local width = 50
    local height = 50

    ---@type vim.api.keyset.win_config
    return {
        relative = "editor",
        width = width,
        height = height,
        row = height,
        col = width,
        border = 'rounded',
        title = 'notes',
        title_pos = 'left',
        anchor = 'NW'
    }
end

local function bufopt_defaults()

    return {
        buftype = "nofile",
        bufhidden = "hide",
        swapfile = false,
        filetype = "markdown"
    }

end

---@class obj
---@field bufnr integer
---@field winid integer
local obj = {}
obj.__index = obj


---@return obj
function obj:bufopt(name, val)
    if type(name) == "table" then
        for k, v in pairs(name) do
            vim.api.nvim_set_option_value(k, v, { scope = 'local', buf = self.bufnr })
        end
    else
        vim.api.nvim_set_option_value(name, val, {scope = 'local', buf = self.bufnr })
    end

    return self
end

---@return obj
function obj:winopt(name, val)
    if type(name) == "table" then
        for k, v in pairs(name) do
            vim.api.nvim_set_option_value(k, v, { scope = 'local', win = self.winid })
        end
    else
        vim.api.nvim_set_option_value(name, val, {scope = 'local', win = self.winid })
    end

    return self
end

---@param conf vim.api.keyset.win_config
---@return obj
function obj:winsetconf(conf)
    local c = vim.tbl_deep_extend('force', vim.api.nvim_win_get_config(self.winid), conf)
    vim.api.nvim_win_set_config(self.winid, c)
    return self
end

---@return integer, integer
function obj:wininfo()
    return self.bufnr, self.winid
end

---@param opts table
---@return obj
function win:new_float(opts)
    self.bufnr = opts.bufnr or vim.api.nvim_create_buf(true, false)
    opts.bufnr = nil

    count = count + 1
    vim.api.nvim_buf_set_name(self.bufnr,"[MS-note-" .. count .. "].md")

    for k, v in pairs(bufopt_defaults()) do
        vim.api.nvim_set_option_value(k, v, { scope = 'local', buf = self.bufnr })
    end

    local win_config = opts and vim.tbl_extend('force', winconfig_default(), opts)
        or winconfig_default()

    self.winid = vim.api.nvim_open_win(self.bufnr, true, win_config)

---@diagnostic disable-next-line: return-type-mismatch
    return setmetatable(win, obj)
end



-- Testing function
---@return table, table
function win:opt_defaults()
    return bufopt_defaults(), {}
end

---@return table, vim.api.keyset.win_config
function win:config_defaults()
    return {}, winconfig_default()
end


return win
