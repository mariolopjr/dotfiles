return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = false,
    priority = 1000,
    init = function()
      vim.cmd.colorscheme 'catppuccin-macchiato'
    end,
    config = function()
      local catppuccin = require('catppuccin')

      catppuccin.setup({
        integrations = {
          neotree = true,
        }
      })
    end,
    opts = {},
  },
}
