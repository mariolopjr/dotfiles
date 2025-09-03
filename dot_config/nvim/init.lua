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

require("options").setup()
require("keymap").setup()
require("lazynvim").setup()
require("lsp").setup()
