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

  event.mappings.LazyFile =
    { id = "LazyFile", event = { "BufReadPost", "BufNewFile", "BufWritePre" } }
  event.mappings["User LazyFile"] = event.mappings.LazyFile

  -- ensure lazy lock file is synced with chezmoi
  -- load before lazy.nvim otherwise LazyInstall will not be caught
  vim.api.nvim_create_autocmd("User", {
    pattern = { "LazyInstall", "LazySync", "LazyUpdate", "LazyClean" },
    callback = function()
      -- run chezmoi add after lockfile update
      local lock_file = require("lazy.core.config").options.lockfile
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

  -- bootstrap lazy
  require("lazy").setup({
    "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically

    -- import plugins
    { import = "plugins" },

    -- keymap
    vim.keymap.set("n", "<leader>pl", "<cmd>Lazy<cr>", { desc = "[P]lugin Lazy" }),
  })
end

return M
