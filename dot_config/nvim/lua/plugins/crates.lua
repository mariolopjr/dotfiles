return {
  {
    "saecki/crates.nvim",
    enabled = not vim.g.vscode,
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup()
    end,
  },
}
