# Things to do

## Goals

- [ ] when user changes config in `ms:setup()` only update relevant winstate
- [ ] consistant type naming. (ie. 'ms.*')
- [ ] polish
    - [ ] handle invalid settings in settings menu better
    - [ ] handle switching between floats and splits while 'close_on_leave' is false

- [ ] refactor window representation
    - bundle buffer/window info into a single object
    - store in lists
    - winbuf is useful here

## Finished

- [x] Fix ui:close_window() in order to move autocommands to file.lua
- [x] *save to a file*
    - [x] Save on close option
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

To save me the trouble of typing it out everytime:

```lua

require('plenary.reload').reload_module('mark-scratch')

local ms = require('mark-scratch')
local logg = require('mark-scratch.logger').logg

local ok, err = pcall(ms.setup, ms, {

})
if not ok then
    logg:log("Error: ", err)
    logg:show()
end

```

