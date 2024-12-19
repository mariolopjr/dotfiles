return {
  {
    "mrjones2014/smart-splits.nvim",
    config = function()
      local smart_splits = require("smart-splits")
      local map = vim.keymap.set
      local opts = { noremap = true, silent = true }

      -- resizing splits
      map("n", "<D-h>", smart_splits.resize_left, opts)
      map("n", "<D-j>", smart_splits.resize_down, opts)
      map("n", "<D-k>", smart_splits.resize_up, opts)
      map("n", "<D-l>", smart_splits.resize_right, opts)

      -- moving between splits
      map("n", "<C-h>", smart_splits.move_cursor_left, opts)
      map("n", "<C-j>", smart_splits.move_cursor_down, opts)
      map("n", "<C-k>", smart_splits.move_cursor_up, opts)
      map("n", "<C-l>", smart_splits.move_cursor_right, opts)
      map("n", "<C-\\>", smart_splits.move_cursor_previous, opts)

      -- swapping buffers between windows
      map("n", "<leader><leader>h", smart_splits.swap_buf_left, opts)
      map("n", "<leader><leader>j", smart_splits.swap_buf_down, opts)
      map("n", "<leader><leader>k", smart_splits.swap_buf_up, opts)
      map("n", "<leader><leader>l", smart_splits.swap_buf_right, opts)
    end,
  },
}
