require("plenary.busted")
local eq, same = assert.equals, assert.are.same

-- Lightweight stubs
local function with_stub(tbl, key, replacement)
    local orig = tbl[key]
    tbl[key] = replacement
    return function() tbl[key] = orig end
end

local lsp_should_be_attached = true
local lsp_should_be_stopped = false

local lsp_start_stub          = function() lsp_should_be_stopped = false return 999 end
local lsp_stop_cli_stub       = function() lsp_should_be_stopped = true end
local lsp_cli_is_stopped_stub = function() return lsp_should_be_stopped end
local lsp_buf_attach_cli_stub = function() lsp_should_be_attached = true end
local lsp_detach_stub         = function() lsp_should_be_attached = false end
local lsp_buf_is_attched_stub = function() return lsp_should_be_attached end


local restores = {}
table.insert(restores, with_stub(vim.lsp, "start", lsp_start_stub))
table.insert(restores, with_stub(vim.lsp, "buf_attach_client", lsp_buf_attach_cli_stub))
table.insert(restores, with_stub(vim.lsp, "client_is_stopped", lsp_cli_is_stopped_stub))
table.insert(restores, with_stub(vim.lsp, "buf_is_attached", lsp_buf_is_attched_stub))
table.insert(restores, with_stub(vim.lsp, "stop_client", lsp_stop_cli_stub))
table.insert(restores, with_stub(vim.lsp, "buf_detach_client", lsp_detach_stub))


local ts_set_stub   = function() end
local ts_add_stub   = function() end
local ts_start_stub = function() end
local ts_stop_stub  = function() end

local ts = vim.treesitter
table.insert(restores, with_stub(ts.query, "set", ts_set_stub))
table.insert(restores, with_stub(ts.language, "add", ts_add_stub))
table.insert(restores, with_stub(ts, "start", ts_start_stub))
table.insert(restores, with_stub(ts, "stop", ts_stop_stub))

local BORDER_PRESETS = {
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

local Scratch = require("mark-scratch")

-- Helpers
local function buf_lines(bufnr)
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
end

local function win_is_valid(winid)
    return winid and vim.api.nvim_win_is_valid(winid)
end

local function wait_for(condition, timeout, interval)
    timeout = timeout or 1000
    interval = interval or 10
    local elapsed = 0
    while not condition() and elapsed < timeout do
        vim.wait(interval)
        elapsed = elapsed + interval
    end
    return condition()
end

---Check if one table is a subset of another
---@param subset table
---@param superset table
---@return boolean
local function is_subset(subset, superset)
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
            if not is_subset(v, w) then return false end
        elseif v ~= w then return false end
    end

    return true
end

local function assert_cfg(expected, actual)
    -- neovim 'expands' some options after theyre set, this accounts for that
    if expected.border then
        expected.border = BORDER_PRESETS[expected.border]
    end

    if expected.title then
        actual.title = actual.title[1][1] == expected.title and expected.title or actual.title
    end

    assert.is.True(is_subset(expected, actual),
        "Expected table isn't a subset of the actual table")
end

-- Tests
describe("mark-scratch high-level API", function()
    before_each(function()
        vim.cmd.tabnew()
        Scratch:setup()
    end)

    after_each(function()
        if Scratch.initialized then
            Scratch:destroy()
        end
        assert.is.True(wait_for(function()
            return not vim.api.nvim_buf_is_valid(Scratch.bufnr) and
                not win_is_valid(Scratch.windnr) and
                not Scratch:validate(true)
        end), "Teardown incomplete")
        vim.cmd.tabclose()
    end)

    it("validates immediately after setup()", function()
        assert.is.True(Scratch:validate(true))
        assert.is.truthy(vim.api.nvim_buf_is_valid(Scratch.bufnr))
        assert.is.True(#vim.api.nvim_get_autocmds({ group = Scratch.augroup }) > 0)
        eq("nofile", vim.bo[Scratch.bufnr].buftype)
        eq("scratchmarkdown", vim.bo[Scratch.bufnr].filetype)
    end)

    it("opens a floating window", function()
        Scratch:open_window()
        local winid = Scratch.windnr or -1
        assert.is.True(win_is_valid(winid))
        local cfg = vim.api.nvim_win_get_config(winid)
        assert_cfg({
            relative = "editor",
        }, cfg)
    end)

    it("clears the buffer contents", function()
        vim.api.nvim_buf_set_lines(Scratch.bufnr, 0, -1, true, { "foo", "bar" })
        same({ "foo", "bar" }, buf_lines(Scratch.bufnr), "buffer lines don't match")
        Scratch:clear()
        same({''}, buf_lines(Scratch.bufnr), "buffer wasn't cleared correctly")
    end)

    it("closes the window—gracefully or forcibly", function()
        Scratch:open_window()
        local winid = Scratch.windnr
        assert.is.True(win_is_valid(winid))
        Scratch:close_window()
        assert.is.True(wait_for(function() return not win_is_valid(Scratch.windnr) end))
    end)

    it("destroys everything (buf, win, augroup, lsp)", function()
        Scratch:open_window()
        local winid, bufnr, aug = (Scratch.windnr or -1), Scratch.bufnr, Scratch.augroup
        Scratch:destroy()
        assert.is.True(wait_for(function()
            local ok_aug, aucmd = pcall(vim.api.nvim_get_autocmds, { group = aug })
            return not vim.api.nvim_buf_is_valid(bufnr) and
                not win_is_valid(winid) and
                (not ok_aug or #aucmd == 0) and
                not Scratch.initialized
        end))
    end)

    it("handles invalid state gracefully", function()
        Scratch.bufnr = -1
        assert.is.False(Scratch:validate(true))
        assert.has_error(function() Scratch:open_window() end)
        assert.has_error(function() Scratch:clear() end)
    end)

    it("triggers autocommands correctly", function()
        Scratch:open_window()
        local winid = Scratch.windnr
        vim.cmd("doautocmd BufLeave")
        assert.is.True(wait_for(function() return not win_is_valid(winid) end))
    end)

    it("executes user commands correctly", function()
        vim.cmd("MSOpen")
        assert.is.True(win_is_valid(Scratch.windnr))
        vim.api.nvim_buf_set_lines(Scratch.bufnr, 0, -1, true, { "foo", "bar" })
        vim.cmd("MSClear")
        same({ '' }, buf_lines(Scratch.bufnr))
        vim.cmd("MSClose")
        assert.is.True(wait_for(function() return not win_is_valid(Scratch.windnr) end))
        vim.cmd("MSDest")
        assert.is.True(wait_for(function() return not Scratch.initialized end))
    end)

    it("destroys everything (buf, win, augroup, lsp)", function()
        Scratch:open_window()
        local winid, bufnr, aug = Scratch.windnr, Scratch.bufnr, Scratch.augroup
        -- Optional: Verify augroup exists before destruction
        local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = aug })
        assert.is.True(ok, "Augroup should exist before destroy")
        assert.is.table(autocmds, "Autocommands should be queryable")
        Scratch:destroy()
        assert.is.True(wait_for(function()
            local ok, _ = pcall(vim.api.nvim_get_autocmds, { group = aug })
            return not vim.api.nvim_buf_is_valid(bufnr) and
                not win_is_valid(winid) and
                not ok and  -- Augroup should be invalid
                not Scratch.initialized
        end), "Destruction incomplete")
    end)
end)

-- Teardown
for _, restore in ipairs(restores) do restore() end
