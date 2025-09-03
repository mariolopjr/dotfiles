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

  -- ensure lazy lock file is synced with chezmoi
  -- load before lazy.nvim otherwise LazyInstall will not be caught
  vim.api.nvim_create_autocmd("User", {
    pattern = { "LazyInstall", "LazySync", "LazyUpdate", "LazyClean" },
    callback = function()
      -- run chezmoi add after lockfile update
      local lock_file = vim.fn.stdpath("config") .. "/lazy-lock.json"
      local command = "chezmoi add " .. lock_file
      vim.fn.system(command)

      -- print a message
      if vim.v.shell_error == 0 then
        vim.notify("updated chezmoi with lazy-lock.json", vim.log.levels.INFO)
      else
        vim.notify("failed to update chezmoi", vim.log.levels.ERROR)
      end
    end,
  })

  -- create LazyFile event
  local event = require("lazy.core.handler.event")

  event.mappings.LazyFile =
    { id = "LazyFile", event = { "BufReadPost", "BufNewFile", "BufWritePre" } }
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
    vim.keymap.set(
      "n",
      "<leader>pL",
      require("lazy").home,
      { desc = "[P]lugin [L]azy" }
    ),

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
