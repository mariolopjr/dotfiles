return {
  {
    "startup-nvim/startup.nvim",
    cond = not vim.g.vscode,
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
    },
    config = function()
      require("startup").setup()
    end,
  },
}
