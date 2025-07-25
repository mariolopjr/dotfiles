return {
  {
    "folke/which-key.nvim",
    event = "VimEnter",
    opts = {
      preset = "helix",
      icons = {
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default whick-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = "<Up> ",
          Down = "<Down> ",
          Left = "<Left> ",
          Right = "<Right> ",
          C = "<C-…> ",
          M = "<M-…> ",
          D = "<D-…> ",
          S = "<S-…> ",
          CR = "<CR> ",
          Esc = "<Esc> ",
          ScrollWheelDown = "<ScrollWheelDown> ",
          ScrollWheelUp = "<ScrollWheelUp> ",
          NL = "<NL> ",
          BS = "<BS> ",
          Space = "<Space> ",
          Tab = "<Tab> ",
          F1 = "<F1>",
          F2 = "<F2>",
          F3 = "<F3>",
          F4 = "<F4>",
          F5 = "<F5>",
          F6 = "<F6>",
          F7 = "<F7>",
          F8 = "<F8>",
          F9 = "<F9>",
          F10 = "<F10>",
          F11 = "<F11>",
          F12 = "<F12>",
        },
      },

      -- Document existing key chains
      spec = {
        { "<leader>a",        group = "[A]I",       mode = { "n", "x" } },
        { "<leader>b",        group = "[B]uffer",   mode = { "n", "x" } },
        { "<leader>c",        group = "[C]ode",     mode = { "n", "x" } },
        { "<leader>d",        group = "[D]ebug" },
        { "<leader>f",        group = "[F]iles" },
        { "<leader>g",        group = "[G]it" },
        { "<leader>p",        group = "[P]lugins" },
        { "<leader>r",        group = "[R]un" },
        { "<leader>s",        group = "[S]earch" },
        -- { "<leader>w", group = "[W]orkspace" },
        { "<leader>t",        group = "[T]ests" },
        { "<leader>h",        group = "Git [H]unk", mode = { "n", "v" } },
        { "<leader><leader>", group = "[ ] Hop" },
      },
    },
  },
}
