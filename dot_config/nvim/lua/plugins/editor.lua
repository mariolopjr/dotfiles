return {
  -- search and replace in multiple files
  {
    "MagicDuck/grug-far.nvim",
    opts = { headerMaxWidth = 80 },
    cmd = "GrugFar",
    keys = {
      {
        "<leader>sr",
        function()
          local grug = require("grug-far")
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          grug.open({
            transient = true,
            prefills = {
              filesFilter = ext and ext ~= "" and "*." .. ext or nil,
            },
          })
        end,
        mode = { "n", "v" },
        desc = "Search and Replace",
      },
    },
  },

  -- labeled jump motions, char mode also enhances f/F/t/T with labels
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      modes = {
        char = { jump_labels = true },
      },
    },
    -- stylua: ignore
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- highlight and browse TODO, HACK, BUG comments
  {
    "folke/todo-comments.nvim",
    event = "LazyFile",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next Todo Comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous Todo Comment",
      },
      {
        "<leader>st",
        function()
          ---@diagnostic disable-next-line: undefined-field
          Snacks.picker.todo_comments()
        end,
        desc = "Todo",
      },
      {
        "<leader>sT",
        function()
          ---@diagnostic disable-next-line: undefined-field
          Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } })
        end,
        desc = "Todo/Fix/Fixme",
      },
    },
  },

  -- split navigation and resizing
  {
    "mrjones2014/smart-splits.nvim",
    version = ">=v1.0.0",
    lazy = false,
    opts = { float_win_behavior = "mux" },
    -- stylua: ignore
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end },
      { "<A-h>", function() require("smart-splits").resize_left() end },
      { "<A-j>", function() require("smart-splits").resize_down() end },
      { "<A-k>", function() require("smart-splits").resize_up() end },
      { "<A-l>", function() require("smart-splits").resize_right() end },
    },
  },
}
