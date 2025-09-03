local M = {}

M.setup = function()
  -- install
  vim.pack.add({
    {
      src = "https://github.com/mrjones2014/smart-splits.nvim",
      version = vim.version.range("6.0.0"),
    },
  })

  -- setup
  require("rustaceanvim").setup()
end

if vim.g.use_vim_pack then
  return M
end

return {
  {
    "mrcjkb/rustaceanvim",
    version = "^6", -- Recommended
    lazy = false, -- This plugin is already lazy
  },
}
