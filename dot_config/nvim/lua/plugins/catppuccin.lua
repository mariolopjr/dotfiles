return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    init = function()
      vim.cmd.colorscheme("catppuccin-macchiato")
    end,
    enabled = not vim.g.vscode,
    opts = {
      integrations = {
        blink_cmp = true,
        leap = true,
        mason = true,
        markdown = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        neotest = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
  },
}
