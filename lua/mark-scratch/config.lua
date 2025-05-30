local M = {}

---@class ms.config.partial.keybinds
---@field open_scratch? string
---@field float_up? string
---@field float_down? string
---@field float_left? string
---@field float_right? string

---@class ms.config.partial.window
---@field wintype? 'float' | 'split'
---@field split_direction? 'above' | 'below' | 'right' | 'left'
---@field vertical? boolean
---@field width? integer
---@field height? integer
---@field float_x? integer
---@field float_y? integer

---@class ms.config.partial
---@field keybinds? ms.config.partial.keybinds
---@field window? ms.config.partial.window

---@class ms.config.keybinds
---@field open_scratch string
---@field float_up string
---@field float_down string
---@field float_left string
---@field float_right string

---@class ms.config.window
---@field wintype 'float' | 'split'
---@field split_direction 'above' | 'below' | 'right' | 'left'
---@field vertical boolean
---@field width integer
---@field height integer
---@field float_x integer
---@field float_y integer

local width = 100
local height = 50

---@class ms.config
---@field keybinds ms.config.keybinds
---@field window ms.config.window
M.default_config = {

    -- TODO:
    -- should close when leaving?

    keybinds = {   -- TODO: Actually setup keybinds
        open_scratch = '<leader>ms',
        float_up    = '<C-Up>',
        float_down  = '<C-Down>',
        float_left  = '<C-Left>',
        float_right = '<C-Right>',
    },

    window = {
        wintype = 'float',
        split_direction = 'right',
        vertical = true,
        width = width,
        height = height,
        float_x = math.floor((vim.o.columns - width) / 2),
        float_y = math.floor((vim.o.lines - height) / 2),
    }

}

return M

