local M = {}

function M.setup()
  -- Setup lazy.nvim
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
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

  -- create LazyFile event
  local event = require("lazy.core.handler.event")

  event.mappings.LazyFile = { id = "LazyFile", event = { "BufReadPost", "BufNewFile", "BufWritePre" } }
  event.mappings["User LazyFile"] = event.mappings.LazyFile

  -- bootstrap lazy
  require("lazy").setup({
    spec = {
      -- import plugins
      { import = "plugins" },
      "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
    },

    install = {
      colorscheme = { "catppuccin-macchiato" },
    },

    -- keymap
    vim.keymap.set("n", "<leader>pL", require("lazy").home, { desc = "[P]lugin [L]azy" }),

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
end

return M
