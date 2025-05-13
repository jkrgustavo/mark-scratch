local Util = require('mark-scratch.tests.utils')

require("plenary.busted")
local eq, same = assert.equals, assert.are.same

---@type Scratch
local Scratch = nil
local MSGroup = nil

-- Helpers
local function buf_lines(bufnr)
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
end

local function win_is_valid(winid)
    return winid and vim.api.nvim_win_is_valid(winid)
end

-- Tests
describe("mark-scratch high-level API", function()
    before_each(function()
        require('plenary.reload').reload_module('mark-scratch')
        MSGroup = require('mark-scratch.augroup')
        Scratch = require('mark-scratch')
        vim.cmd.tabnew()
        Scratch:setup()
    end)

    after_each(function()
        if Scratch.initialized then
            Scratch:destroy()
        end
        assert.is.True(Util.wait_until(function()
            return not vim.api.nvim_buf_is_valid(Scratch.bufnr) and
                not win_is_valid(Scratch.windnr) and
                not Scratch:validate(true)
        end), "Teardown incomplete")

        require('plenary.reload').reload_module('mark-scratch')
        vim.cmd.tabclose()
    end)

    it("validates immediately after setup()", function()
        assert.is.True(Scratch:validate(true))
        assert.is.truthy(vim.api.nvim_buf_is_valid(Scratch.bufnr))
        assert.is.True(#vim.api.nvim_get_autocmds({ group = MSGroup }) > 0)
        eq("nofile", vim.bo[Scratch.bufnr].buftype)
        eq("scratchmarkdown", vim.bo[Scratch.bufnr].filetype)
    end)

    it("opens a floating window", function()
        Scratch:open_window()
        local winid = Scratch.windnr or -1
        assert.is.True(win_is_valid(winid))
        local cfg = vim.api.nvim_win_get_config(winid)
        assert(Util.wincfg_equal({
            relative = "editor",
        }, cfg))
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
        assert.is.True(Util.wait_until(function() return not win_is_valid(Scratch.windnr) end))
    end)

    it("destroys everything (buf, win, augroup, lsp)", function()
        Scratch:open_window()
        local winid, bufnr, aug = (Scratch.windnr or -1), Scratch.bufnr, MSGroup
        Scratch:destroy()
        assert.is.True(Util.wait_until(function()
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
        assert.is.True(Util.wait_until(function() return not win_is_valid(winid) end))
    end)

    it("executes user commands correctly", function()
        vim.cmd("MSOpen")
        assert.is.True(win_is_valid(Scratch.windnr))
        vim.api.nvim_buf_set_lines(Scratch.bufnr, 0, -1, true, { "foo", "bar" })
        vim.cmd("MSClear")
        same({ '' }, buf_lines(Scratch.bufnr))
        vim.cmd("MSClose")
        assert.is.True(Util.wait_until(function() return not win_is_valid(Scratch.windnr) end))
        vim.cmd("MSDest")
        assert.is.True(Util.wait_until(function() return not Scratch.initialized end))
    end)

    it("destroys everything (buf, win, augroup, lsp)", function()
        Scratch:open_window()
        local winid, bufnr, aug = Scratch.windnr, Scratch.bufnr, MSGroup
        -- Optional: Verify augroup exists before destruction
        local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = aug })
        assert.is.True(ok, "Augroup should exist before destroy")
        assert.is.table(autocmds, "Autocommands should be queryable")
        Scratch:destroy()
        assert.is.True(Util.wait_until(function()
            ok, _ = pcall(vim.api.nvim_get_autocmds, { group = aug })
            return not vim.api.nvim_buf_is_valid(bufnr) and
                not win_is_valid(winid) and
                not ok and  -- Augroup should be invalid
                not Scratch.initialized
        end), "Destruction incomplete")
    end)
end)

-- Teardown
-- stub:restore()
