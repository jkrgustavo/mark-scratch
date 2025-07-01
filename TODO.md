# Things to do

## Goals

- [ ] when user changes config in `ms:setup()` only update relavent winstate
- [ ] *save to a file*
- [ ] refactor window representation
    - bundle buffer/window info into a single object
    - store in lists
    - winbuf is useful here

## Finished

- [x] *save horizontal and vertical splits seperately*
- [x] change keybinds to toggle instead of just open
- [x] update prompt text with current wintype settings dynamically
- [x] lazy initialize lsp
- [x] *dynamic settings ui*
- [x] represent splits and floats better
- [x] save split and float states seperately (better experience switching between)
- [x] move winstate to its own module
- [x] Flesh out winstate more
- [x] Convert modules to singletons
- [x] Refactor ui so it doesn't use `ui.new()` and `ui:setup()`
- [x] move lsp to be part of ui

## Misc

```lua

-- Helper function to load local plugins
local function load_dev_plugin(plugin_name)
    local dev_path = vim.fn.getcwd()
    vim.opt.runtimepath:append(dev_path)
    package.loaded[plugin_name] = nil
    return require(plugin_name)
end

require('plenary.reload').reload_module('mark-scratch')

local ms = require('mark-scratch')
local logg = require('mark-scratch.logger').logg

local ok, err = pcall(ms.setup, ms, {
    window = {
        wintype = 'split',
        split_direction = 'right',
        vertical = true
    }
})
if not ok then
    logg:log("Error: ", err)
    logg:show()
end


-- local bufnr = vim.fn.bufnr(-1, true)
-- vim.bo[bufnr].buftype = 'nofile'
-- vim.bo[bufnr].swapfile = false
-- vim.bo[bufnr].modifiable = false
-- vim.bo[bufnr].bufhidden = 'wipe'
--
-- local winid = vim.api.nvim_open_win(bufnr, false, {
--     relative = 'editor',
--     row = 10,
--     col = 10,
--     width = 20,
--     height = 20
-- })
--
-- vim.api.nvim_create_user_command('OOP', function()
--     vim.api.nvim_win_close(winid, true)
-- end, {})
--
-- vim.api.nvim_create_user_command('POO', function()
--     vim.api.nvim_win_set_config(winid, {
--         row = 20,
--         col = 20,
--         width = 40,
--         height = 40
--     })
-- end, {})



```

