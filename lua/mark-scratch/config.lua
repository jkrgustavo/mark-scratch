local M = {}

---@class ms.config.keybinds
---@field open_scratch string
---@field float_up string
---@field float_down string
---@field float_left string
---@field float_right string

---@class ms.config.window
---@field wintype 'float' | 'vsplit' | 'hsplit'
---@field split_direction 'botright' | 'botleft' | 'topright' | 'topleft'
---@field width integer
---@field height integer
---@field float_x integer
---@field float_y integer

---@class ms.config.partial.keybinds
---@field open_scratch? string
---@field float_up? string
---@field float_down? string
---@field float_left? string
---@field float_right? string

---@class ms.config.partial.window
---@field wintype? 'float' | 'vsplit' | 'hsplit'
---@field split_direction? 'botright' | 'botleft' | 'topright' | 'topleft'
---@field width? integer
---@field height? integer
---@field float_x? integer
---@field float_y? integer

---@class ms.config.partial
---@field keybinds? ms.config.keybinds
---@field window? ms.config.window

---@class ms.config
---@field keybinds ms.config.keybinds
---@field window ms.config.window
M.default_config = {
    keybinds = {
        open_scratch = '<leader>ms',
        float_up    = '<C-Up>',
        float_down  = '<C-Down>',
        float_left  = '<C-Left>',
        float_right = '<C-Right>',
    },

    window = {
        wintype = 'float',
        split_direction = 'botright',
        width = 100,
        height = 75,
        float_x = math.floor((vim.o.columns - 100) / 2),
        float_y = math.floor((vim.o.lines - 75) / 2),
    }
}




return M
