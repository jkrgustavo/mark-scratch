local M = {}

---@class ms.config.partial.keybinds
---@field toggle_menu? string
---@field toggle_scratch? string
---@field float_up? string
---@field float_down? string
---@field float_left? string
---@field float_right? string

---@class ms.config.partial.window
---@field wintype? 'float' | 'vertical' | 'horizontal'
---@field split_direction? 'above' | 'below' | 'right' | 'left'
---@field width? integer
---@field height? integer
---@field float_x? integer
---@field float_y? integer
---@field close_on_leave? boolean

---@class ms.config.partial
---@field keybinds? ms.config.partial.keybinds
---@field window? ms.config.partial.window

---@class ms.config.keybinds
---@field toggle_menu string
---@field toggle_scratch string
---@field float_up string
---@field float_down string
---@field float_left string
---@field float_right string

---@class ms.config.window
---@field wintype 'float' | 'vertical' | 'horizontal'
---@field split_direction 'above' | 'below' | 'right' | 'left'
---@field width integer
---@field height integer
---@field float_x integer
---@field float_y integer
---@field close_on_leave boolean

local width = 100
local height = 50

---@class ms.config
---@field keybinds ms.config.keybinds
---@field window ms.config.window
M.default_config = {

    keybinds = {
        toggle_menu    = '<leader>mo',
        toggle_scratch = '<leader>ms',
        float_up       = '<leader><Up>',
        float_down     = '<leader><Down>',
        float_left     = '<leader><Left>',
        float_right    = '<leader><Right>',
    },

    window = {
        wintype = 'float',
        split_direction = 'right',
        vertical = true,
        width = width,
        height = height,
        float_x = math.floor((vim.o.columns - width) / 2),
        float_y = math.floor((vim.o.lines - height) / 2),
        close_on_leave = true
    }

}

return M

