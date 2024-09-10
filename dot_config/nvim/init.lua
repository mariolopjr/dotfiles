-- set <space> as the leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- enable nerd fonts
vim.g.have_nerd_font = true

-- Disable netrw at the start of your config
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require 'options'.setup()
require 'keymap'.setup()
require 'lazynvim'.setup()

-- vim: ts=2 sts=2 sw=2 et
