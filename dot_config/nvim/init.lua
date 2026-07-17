-- leader keys must be set before plugins load
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- enable nerd fonts
vim.g.have_nerd_font = true

-- disable netrw, the snacks explorer replaces it
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.miseenv")
require("config.exrc")
require("config.lazy")

-- tmux-style tabline, set up after lazy so the catppuccin palette is available
require("util.tabline").setup()

-- coverage gutters, set up after lazy so the colorscheme cannot clear the
-- highlight links it defines
require("util.coverage").setup()

-- LSP hover float styling, set up after lazy for the same reason as above
require("hoverboard").setup()
