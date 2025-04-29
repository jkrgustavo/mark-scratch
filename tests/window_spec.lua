-- tests/mark‑scratch_spec.lua
local Scratch = require("mark-scratch"):test()

local eq   = assert.equals
local same = assert.are.same

-- ---------------------------------------------------------------------------
-- helpers -------------------------------------------------------------------
-- ---------------------------------------------------------------------------

---Compare every option in |opts| with the real value on |scope|
---@param scope string
---@param handle integer
---@param opts table
local function assert_opts(scope, handle, opts)
    for k, v in pairs(opts) do
        eq(v, vim.api.nvim_get_option_value(k, { [scope] = handle }),
            ("%s option %q mismatch"):format(scope, k))
    end
end

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


local function assert_config(expected, actual)
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

-- Holds the most‑recently‑created win/buf so after_each can clean them up
local current = { bufnr = nil, winid = nil }

---@return integer, integer, obj
local function create_scratch(opts)
    local obj = Scratch:new_float(opts)
    local bufnr, winid = obj:wininfo()
    current.bufnr, current.winid = bufnr, winid
    return bufnr, winid, obj
end

-- ---------------------------------------------------------------------------
-- spec block ----------------------------------------------------------------
-- ---------------------------------------------------------------------------
describe("mark‑scratch window factory", function()

    before_each(function()
        vim.cmd("tabnew")            -- keep tests isolated in their own tabpage
    end)

    after_each(function()
        local winid, bufnr = current.winid, current.bufnr
        if winid and vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_win_close(winid, true)
        end
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
            vim.bo[bufnr].buflisted = false
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        current.bufnr, current.winid = nil, nil
        vim.cmd("tabclose")          -- return to previous tabpage
    end)

    it("applies default buffer and window options", function()
        local bufnr, winid = create_scratch({})
        local bufdef, windef = Scratch:opt_defaults()

        local _, defwincon = Scratch:config_defaults()
        local vimwincon = vim.api.nvim_win_get_config(winid)

        assert_config(defwincon, vimwincon)

        -- make sure default opts match bufnr's and winid's
        assert_opts("buf", bufnr, bufdef)
        assert_opts("win", winid, windef)
    end)


    it("honours options passed to :new_float()", function()
        ---@type vim.api.keyset.win_config
        local custom = {
            title     = "abc123",
            title_pos = "right",
            width     = 100,
            height    = 75,
            relative  = 'win',
            row       = 50,
            col       = 50,
            border    = "shadow",
        }

        local bufnr, winid = create_scratch(custom)
        local bufdef, windef = Scratch:opt_defaults()       -- default options
        local _, windefaults = Scratch:config_defaults()    -- default configs

        -- Merge the new config with the default and compare to actual values
        local merwinconf = vim.tbl_extend("keep", custom, windefaults)
        local vimwinconf = vim.api.nvim_win_get_config(winid)
        assert_config(merwinconf, vimwinconf)

        -- Make sure the other options didn't change
        assert_opts("buf", bufnr, bufdef)
        assert_opts("win", winid, windef)
    end)

    it("changes config afterwards with :winsetconf()", function()
        local bufnr, winid, obj = create_scratch({})
        local bufdef, windef = Scratch:opt_defaults()

        local new_conf = { width = 80, height = 40, title = "changed" }
        obj:winsetconf(new_conf)

        assert_config(new_conf, vim.api.nvim_win_get_config(winid))

        assert_opts("buf", bufnr, bufdef)
        assert_opts("win", winid, windef)
    end)

    it("sets multiple win opts via :winopt()", function()
        local opts = { winhighlight = "Normal:Error", number = false }
        local bufnr, winid, obj = create_scratch({})

        local bufdef, _ = Scratch:opt_defaults()
        local _, defwincon = Scratch:config_defaults()

        obj:winopt(opts)

        assert_config(defwincon, vim.api.nvim_win_get_config(winid))
        assert_opts("buf", bufnr, bufdef)
        assert_opts("win", winid, opts)
    end)

    it("sets multiple buf opts via :bufopt()", function()
        local opts = { filetype = "lua", bufhidden = "wipe" }
        local bufnr, winid, obj = create_scratch({})

        local _, windef = Scratch:opt_defaults()
        local _, defwincon = Scratch:config_defaults()

        obj:bufopt(opts)

        assert_config(defwincon, vim.api.nvim_win_get_config(winid))
        assert_opts("buf", bufnr, opts)
        assert_opts("win", winid, windef)
    end)

    it("re‑uses an existing buffer if provided", function()
        local initial_buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(initial_buf, "[initial‑buf].lua")
        vim.api.nvim_set_option_value("filetype", "lua", { buf = initial_buf })

        local bufnr = select(1, create_scratch({ bufnr = initial_buf }))
        eq(initial_buf, bufnr, "the passed‑in buffer should be reused")
    end)
end)
