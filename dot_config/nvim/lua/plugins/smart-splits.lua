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
  vim.keymap.set("n", "<C-h>", smart_splits.move_cursor_left)
  vim.keymap.set("n", "<C-j>", smart_splits.move_cursor_down)
  vim.keymap.set("n", "<C-k>", smart_splits.move_cursor_up)
  vim.keymap.set("n", "<C-l>", smart_splits.move_cursor_right)
  vim.keymap.set("n", "<C-\\>", smart_splits.move_cursor_previous)

  vim.keymap.set("n", "<A-h>", smart_splits.resize_left)
  vim.keymap.set("n", "<A-j>", smart_splits.resize_down)
  vim.keymap.set("n", "<A-k>", smart_splits.resize_up)
  vim.keymap.set("n", "<A-l>", smart_splits.resize_right)
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
