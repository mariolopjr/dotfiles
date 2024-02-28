-- set initial config
vim.g.mapleader = " "

require 'plugins'.setup()
require 'keybindings.shared'.setup()

-- TODO: move to a better place, potentially a separate file for vscode-specific configuration
if vim.g.vscode then
    -- https://github.com/vscode-neovim/vscode-neovim/issues/298
    vim.opt.clipboard:append("unnamedplus")

    local function print_plugins()
        local plugins = require("lazy").plugins()
        for _, plugin in pairs(plugins) do
            if plugin.name ~= nil then
                print(plugin.name)
            end
        end
    end
    print_plugins()
    print("VSCode specific configuration loaded")
end
