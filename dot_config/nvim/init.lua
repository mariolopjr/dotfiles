-- set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- enable nerd fonts
vim.g.have_nerd_font = true

-- Disable netrw at the start of your config
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

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

require("options").setup()
require("keymap").setup()
require("lazynvim").setup()

-- enter telescope when loading neovim
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.bo.filetype ~= "" then
      return
    end

    if #vim.fn.argv() ~= 0 then
      require("telescope.builtin").find_files({ hidden = true })
    end
  end,
})
