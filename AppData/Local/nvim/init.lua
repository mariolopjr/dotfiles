-- set initial config
vim.g.mapleader = " "

require 'plugins'.setup()
require 'keybindings.shared'.setup()

-- Check if running neovim or vscode-neovim and applies custom configuration
if not vim.g.vscode then
    -- TBD
else
    -- https://github.com/vscode-neovim/vscode-neovim/issues/298
    vim.opt.clipboard:append("unnamedplus")
end
