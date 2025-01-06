local M = {}

function M.setup()
  -- make line numbers default with relative numbers enabled
  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.mouse = "a"
  vim.opt.showmode = false
  vim.opt.cursorline = true
  vim.opt.termguicolors = true

  vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
  end)

  -- enable modelines
  vim.opt.modeline = true

  -- Enable break indent
  vim.opt.breakindent = true

  -- Save undo history
  vim.opt.undofile = true

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  vim.opt.ignorecase = true
  vim.opt.smartcase = true

  -- Keep signcolumn on by default
  vim.opt.signcolumn = "yes"

  -- Decrease update time
  vim.opt.updatetime = 250

  -- Decrease mapped sequence wait time
  -- Displays which-key popup sooner
  vim.opt.timeoutlen = 300

  -- Configure how new splits should be opened
  vim.opt.splitright = true
  vim.opt.splitbelow = true

  -- Sets how neovim will display certain whitespace characters in the editor.
  --  See `:help 'list'`
  --  and `:help 'listchars'`
  vim.opt.list = true
  vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

  -- Preview substitutions live, as you type!
  vim.opt.inccommand = "split"

  -- Minimal number of screen lines to keep above and below the cursor.
  vim.opt.scrolloff = 10

  -- treesitter folding
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
  vim.opt.foldcolumn = "0"
  vim.opt.foldtext = "" -- first line of fold will have syntax highlighting
  vim.opt.foldlevel = 5 -- ensure file is unfolded
  vim.opt.foldnestmax = 4 -- only fold up to 4 levels deep
end

return M
