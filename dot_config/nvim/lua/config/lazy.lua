-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- LazyFile fires the first time a real file is read or written
local event = require("lazy.core.handler.event")
event.mappings.LazyFile =
  { id = "LazyFile", event = { "BufReadPost", "BufNewFile", "BufWritePre" } }
event.mappings["User LazyFile"] = event.mappings.LazyFile

require("lazy").setup({
  spec = {
    { import = "plugins" },
    { import = "plugins.lang" },
    "tpope/vim-sleuth", -- detect tabstop and shiftwidth automatically
  },

  install = {
    colorscheme = { "catppuccin-macchiato" },
  },

  -- disable additional built-in plugins
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

vim.keymap.set(
  "n",
  "<leader>pL",
  require("lazy").home,
  { desc = "[P]lugin [L]azy" }
)
