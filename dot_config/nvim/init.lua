-- set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- enable nerd fonts
vim.g.have_nerd_font = true

-- Disable netrw at the start of your config
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("options").setup()
require("keymap").setup()
require("lazynvim").setup()

-- enter telescope when loading neovim
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.bo.filetype ~= "" then
      return
    end

    if #vim.fn.argv() == 0 then
      require("telescope.builtin").find_files({ cwd = vim.loop.cwd(), hidden = true })
      return
    end

    require("telescope.builtin").find_files({ hidden = true })
  end,
})
