-- set initial config
vim.g.mapleader = " "

-- TODO: move to a better place, potentially a separate file for vscode-specific configuration
if vim.g.vscode then
    -- https://github.com/vscode-neovim/vscode-neovim/issues/298
    vim.opt.clipboard:append("unnamedplus")
end

require 'plugins'.setup()
require 'keybindings.shared'.setup()
