-- Highlight todo, notes, etc in comments
return {
  {
    "folke/todo-comments.nvim",
    enabled = not vim.g.vscode,
    event = "VimEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
  },
}
