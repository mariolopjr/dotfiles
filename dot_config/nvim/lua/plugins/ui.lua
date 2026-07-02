return {
  -- fancy cmdline, messages and LSP markdown rendering
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      lsp = {
        -- override markdown rendering so hover and signature docs use treesitter
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
        },
      },
      presets = {
        bottom_search = true, -- classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages go to a split
      },
    },
  },

  -- keymap hints popup
  {
    "folke/which-key.nvim",
    event = "VimEnter",
    opts = {
      preset = "helix",
      icons = {
        mappings = vim.g.have_nerd_font,
        -- nf-fa-wrench for the buffer-local <leader>j just picker, see plugins/just.lua
        rules = {
          { pattern = "%[j%]ust", icon = "\u{f0ad}", color = "orange" },
        },
      },

      -- document key chain groups
      spec = {
        { "<leader>a", group = "[A]I", mode = { "n", "x" } },
        { "<leader>b", group = "[B]uffer", mode = { "n", "x" } },
        { "<leader>c", group = "[C]ode", mode = { "n", "x" } },
        { "<leader>d", group = "[D]ebug" },
        { "<leader>f", group = "[F]iles" },
        { "<leader>g", group = "[G]it" },
        { "<leader>p", group = "[P]lugins" },
        { "<leader>r", group = "[R]un" },
        { "<leader>s", group = "[S]earch" },
        { "<leader>t", group = "[T]ests" },
        { "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
      },
    },
  },
}
