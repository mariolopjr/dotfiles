-- set initial config
vim.g.mapleader = " "

-- check if running in vscode
if vim.g.vscode then
    -- https://github.com/vscode-neovim/vscode-neovim/issues/298
    vim.opt.clipboard:append("unnamedplus")
end

require 'plugins'.setup()
require 'keybindings.shared'.setup()
