local Utils = require('mark-scratch.utils')
local Winbuf = require('mark-scratch.winbuf')
local Winstate = require('mark-scratch.winstate')
local Config = require('mark-scratch.config')
local Logg = require('mark-scratch.logger').logg
local AuGroup = require('mark-scratch.augroup')

local Path = require('plenary.path')

local data_path = vim.fn.stdpath('data') .. "/markscratch"
-- local data_path = "./" .. "test"

---@alias abspath string

---@class ms.datafile.winstates
---@field float ms.winstate.float
---@field vertical ms.winstate.split.vertical
---@field horizontal ms.winstate.split.horizontal

---@class ms.datafile.metadata
---@field root string
---@field winstates ms.datafile.winstates

---@class ms.datafile
---@field metadata ms.datafile.metadata
---@field data string

local function setup_data_path()
    local path = Path:new(data_path)

    if not path:exists() then
        path:mkdir()
    end
end


local function get_root()
    ---@type Path | nil
    local path = Path:new(vim.uv.cwd()):find_upwards('.git')

    if not path then
        Logg:log("Searched upwards but couldn't find a git file. Cwd: ", vim.uv.cwd())
        error("Useage outside a git repository is unsupported lol")
    end

    return path:parent():absolute()
end

---@param path abspath
local function filepath(path)
    return ("%s/%s.json"):format(data_path, vim.fn.sha256(path))
end

---@param abspath abspath
---@return ms.datafile | nil
local function read_datafile(abspath)
    setup_data_path()

    ---@type Path
    local datafile = Path:new(filepath(abspath))

    if not datafile:exists() then
        return
    end

    local contents = datafile:read()
    if not contents or contents == "" then
        return
    end

    local ok, decoded = pcall(vim.json.decode, contents)
    if not ok then
        Logg:log("Error decoding datafile: " .. decoded, abspath)
        return
    end

    return decoded
end

---@param abspath abspath
---@param data ms.datafile
local function write_datafile(abspath, data)
    ---@type Path
    local path = Path:new(filepath(abspath))

    if not path:exists() then
        path:touch()
    end

    local msdata = vim.json.encode(data)
    path:write(msdata, "w")
end

---@param f ms.file
local function setup_autocommands(f)

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        buffer = f.bufnr,
        once = false,
        group = AuGroup,
        callback = function()
            if f.config.window.close_on_leave then
                require('mark-scratch').ui:close_window()
            end

            vim.bo[f.bufnr].modified = false
        end
    })

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        buffer = f.bufnr,
        once = false,
        group = AuGroup,
        callback = function()
            if not f.config.window.close_on_leave then
                require('mark-scratch').ui:close_window()
            end

            vim.bo[f.bufnr].modified = false
        end
    })

    vim.api.nvim_create_autocmd({ 'BufWriteCmd' }, {
        buffer = f.bufnr,
        group = AuGroup,
        callback = function()
            f:save()
            vim.bo[f.bufnr].modified = false
        end
    })

    vim.api.nvim_create_autocmd({ "VimLeavePre"}, {
        buffer = f.bufnr,
        group = AuGroup,
        once = true,
        callback = function()
            vim.notify("Quitting", vim.log.levels.ERROR)
            require('mark-scratch'):destroy()
        end,
    })
end

---@class ms.file
---@field root string
---@field bufnr integer
---@field metadata? ms.datafile.metadata
---@field config ms.config
local File = {}
File.__index = File

local count = 0

local function new()
    local f = setmetatable({
        config = Config.default_config,
        root = get_root(),
        bufnr = -1
    }, File)

    count = count + 1
    f.bufnr = Winbuf
        :new({ scratch = true, name = ("[ms | %d].md"):format(count) })
        :bufopt({
            ['filetype'] = "scratchmarkdown",
            ['tabstop'] = 2,
            ['shiftwidth'] = 2,
            ['buflisted'] = false,
            ['buftype'] = 'acwrite'
        })
        :bufinfo()

    local data = read_datafile(f.root)
    if data then
        f.metadata = data.metadata

        local md_lines = Utils.str_lines(data.data)
        vim.api.nvim_buf_set_lines(f.bufnr, 0, #md_lines, false, md_lines)
        vim.bo[f.bufnr].modified = false
    end


    return f
end

---@param config? ms.config.partial
function File:setup(config)
    config = config or {}
    self.config = vim.tbl_deep_extend('force', self.config, config)

    setup_autocommands(self)

    if self.metadata and self.config.file_overrides_cfg then

        for k, v in pairs(self.metadata.winstates) do
            Winstate.prev[k] = v
        end
        local winstate = setmetatable({}, Winstate.mt(function() end))
        local active_wstate = self.metadata.winstates[self.config.window.wintype]

        Logg:log("Updating active winstate with: ", active_wstate)

        for k, v in pairs(active_wstate) do
            winstate[k] = v
        end
    end
end

function File:save()
    if not require('mark-scratch').initialized then Logg:log("save outside lifecycle") return end

    local datawinstates = {}
    local wstate = setmetatable({}, Winstate.mt(function() end))

    for k, v in pairs(Winstate.prev) do
        if k == wstate.wintype then
            datawinstates[k] = Winstate.get_current_winstate()
        else
            datawinstates[k] = v
        end
    end

    local lc = vim.api.nvim_buf_line_count(self.bufnr)
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, lc, false)
    local f = table.concat(lines, '\n')
    Logg:log("Saved file: ", lc, lines, f)

    ---@type ms.datafile
    local data = {
        metadata = {
            winstates = datawinstates,
            root = self.root
        },

        data = f
    }

    Logg:log(("Saving scratch to %s. Metadata: "):format(data_path), data.metadata)

    vim.print("Scratch file saved.")

    write_datafile(self.root, data)
end

function File:shutdown()

    if self.config.save_on_vimexit then self:save() end


    if vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.bo[self.bufnr].buflisted = false
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    local shutdown = Utils.wait_until(function()
        return not vim.api.nvim_buf_is_valid(self.bufnr)
    end)

    if not shutdown then
        Logg:log("timeout waiting for 'buf_is_valid' to return false", self)
    else
        Logg:log("File is shutdown")
    end
end

local file = new()

return file
