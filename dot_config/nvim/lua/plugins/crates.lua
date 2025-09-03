local M = {}

M.setup = function()
  -- install
  vim.pack.add({
    { src = "https://github.com/saecki/crates.nvim", version = "stable" },
  })

  require("crates").setup({})
end

if vim.g.use_vim_pack then
  return M
end

return {
  {
    "saecki/crates.nvim",
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup({})
    end,
  },
}
