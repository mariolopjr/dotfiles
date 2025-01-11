local M = {}

local keymap = vim.keymap
function M.setup()
  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

  -- Diagnostic keymaps
  keymap.set(
    "n",
    "<leader>q",
    vim.diagnostic.setloclist,
    { desc = "Open diagnostic [Q]uickfix list" }
  )

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  --
  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
  keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

  -- TIP: Disable arrow keys in normal mode
  keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
  keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
  keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
  keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  -- Highlight when yanking (copying) text
  --  Try it with `yap` in normal mode
  --  See `:help vim.highlight.on_yank()`
  vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
      vim.highlight.on_yank()
    end,
  })
end

-- Add autosaving and saving with <leader>fw
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  callback = function()
    if vim.bo.modified and not vim.bo.readonly and vim.bo.buftype == "" then
      vim.cmd("silent update")
    end
  end,
})

keymap.set(
  "n",
  "<leader>bd",
  ":bd<CR>",
  { desc = "[B]uffer [D]elete", noremap = true, silent = true }
)
keymap.set("n", "<leader>fw", ":w<CR>", { desc = "[F]ile [W]rite", noremap = true, silent = true })
keymap.set("n", "<leader>fq", ":q<CR>", { desc = "[F]ile [Q]uit", noremap = true, silent = true })
keymap.set(
  "n",
  "<leader>Q",
  ":cquit<CR>",
  { desc = "[Q]uit Neovim", noremap = true, silent = true }
)

return M
