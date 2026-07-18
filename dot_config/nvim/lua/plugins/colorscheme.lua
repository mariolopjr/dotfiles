return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      -- floats share the editor background so the rounded border blends into it
      custom_highlights = function(c)
        return {
          NormalFloat = { bg = c.base },
          FloatBorder = { bg = c.base, fg = c.blue },
          -- rust-analyzer marks unsafe usages with the `unsafe` semantic token
          -- modifier
          ["@lsp.mod.unsafe.rust"] = { fg = c.maroon },
          ["@lsp.typemod.keyword.unsafe.rust"] = { fg = c.maroon, bold = true },
          ["@lsp.typemod.function.unsafe.rust"] = {
            fg = c.maroon,
            underline = true,
          },
          ["@lsp.typemod.operator.unsafe.rust"] = { fg = c.maroon },
          -- inactive cfg blocks stay readable but dimmed
          DiagnosticUnnecessary = { fg = c.overlay1 },
        }
      end,
      integrations = {
        blink_cmp = true,
        dap = true,
        dap_ui = true,
        flash = true,
        grug_far = true,
        markdown = true,
        mini = { enabled = true },
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
        noice = true,
        render_markdown = true,
        snacks = true,
        treesitter = true,
        which_key = true,
      },
    },
    config = function(_, opts)
      -- setup must run before the colorscheme loads so integrations apply
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-macchiato")
    end,
  },
}
