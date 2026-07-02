-- line numbers with relative numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.showmode = false
vim.opt.cursorline = true
vim.opt.termguicolors = true

-- fish as the default shell when available
local fish = vim.fn.exepath("fish")
if fish ~= "" then
  vim.o.shell = fish
end

-- defer clipboard sync, it can add noticeable startup time
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)

-- enable modelines
vim.opt.modeline = true

-- enable break indent
vim.opt.breakindent = true

-- save undo history
vim.opt.undofile = true

-- case-insensitive searching unless \C or capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- decrease update time
vim.opt.updatetime = 250

-- decrease mapped sequence wait time so which-key pops up sooner
vim.opt.timeoutlen = 300

-- open new splits to the right and below
vim.opt.splitright = true
vim.opt.splitbelow = true

-- display certain whitespace characters, see :help 'listchars'
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- preview substitutions live as you type
vim.opt.inccommand = "split"

-- minimal number of screen lines to keep above and below the cursor
vim.opt.scrolloff = 10

-- treesitter folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldcolumn = "0"
vim.opt.foldtext = "" -- first line of fold keeps syntax highlighting
vim.opt.foldlevel = 5 -- ensure file is unfolded
vim.opt.foldnestmax = 4 -- only fold up to 4 levels deep

-- tabs are 4 spaces wide by default
vim.opt.tabstop = 4

-- load .nvim.lua from the cwd and parent directories at startup
vim.o.exrc = true

-- force .h files to c
vim.g.c_syntax_for_h = true

-- ledger file support
vim.filetype.add({
  extension = { ledger = "ledger", ldg = "ledger", journal = "ledger" },
})
