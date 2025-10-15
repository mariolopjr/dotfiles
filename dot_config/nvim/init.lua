-- set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- enable nerd fonts
vim.g.have_nerd_font = true

-- disable netrw at the start of your config
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- enable vim.pack
vim.g.use_vim_pack = false

require("options").setup()
require("keymap").setup()
require("lazynvim").setup()
require("lsp").setup()
