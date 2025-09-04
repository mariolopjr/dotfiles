local M = {}

M.setup = function()
  -- install
  vim.pack.add({
    {
      src = "https://github.com/mrjones2014/smart-splits.nvim",
      version = vim.version.range("1.0.0"),
    },
  })

  -- setup
  local smart_splits = require("smart-splits")
  smart_splits.setup()

  -- keymaps
  local map = vim.keymap.set
  map("n", "<C-h>", smart_splits.move_cursor_left)
  map("n", "<C-j>", smart_splits.move_cursor_down)
  map("n", "<C-k>", smart_splits.move_cursor_up)
  map("n", "<C-l>", smart_splits.move_cursor_right)
  map("n", "<C-\\>", smart_splits.move_cursor_previous)

  map("n", "<A-h>", smart_splits.resize_left)
  map("n", "<A-j>", smart_splits.resize_down)
  map("n", "<A-k>", smart_splits.resize_up)
  map("n", "<A-l>", smart_splits.resize_right)
end

if vim.g.use_vim_pack then
  return M
end

return {
  {
    "mrjones2014/smart-splits.nvim",
    version = ">=v1.0.0",
    lazy = false,
    keys = {
      {
        "<C-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
      },
      {
        "<C-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
      },
      {
        "<C-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
      },
      {
        "<C-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
      },
      {
        "<A-h>",
        function()
          require("smart-splits").resize_left()
        end,
      },
      {
        "<A-j>",
        function()
          require("smart-splits").resize_down()
        end,
      },
      {
        "<A-k>",
        function()
          require("smart-splits").resize_up()
        end,
      },
      {
        "<A-l>",
        function()
          require("smart-splits").resize_right()
        end,
      },
    },
  },
}
