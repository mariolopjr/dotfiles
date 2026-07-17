return {
  -- fancy cmdline, messages and LSP markdown rendering
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      lsp = {
        -- keep hover on the native float since hoverboard styles it
        hover = { enabled = false },
      },
      presets = {
        bottom_search = true, -- classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages go to a split
      },
      views = {
        -- rounded, padded K hover popup
        hover = {
          border = { style = "rounded", padding = { 0, 1 } },
          size = { max_width = 90 },
        },
      },
    },
  },

  -- render-markdown attaches to nofile floats by default
  -- disable it for floats as hoverboard styles those
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      overrides = {
        buftype = {
          nofile = { enabled = false },
        },
      },
    },
  },

  -- keymap hints popup
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
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
        { "<leader>l", group = "[L]SP" },
        { "<leader>o", group = "[O]bsidian", mode = { "n", "x" } },
        { "<leader>p", group = "[P]lugins" },
        { "<leader>r", group = "[R]un" },
        { "<leader>s", group = "[S]earch" },
        { "<leader>S", group = "[S]ession" },
        { "<leader>t", group = "[T]abs" },
        { "<leader>T", group = "[T]ests" },
        { "<leader>x", group = "[x] Todos" },
        { "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
      },
    },
  },
}
