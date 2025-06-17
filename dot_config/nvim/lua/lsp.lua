local M = {}

M.setup = function()
  vim.lsp.enable({
    "clangd",
    "fish_lsp",
    "gopls",
    "lua_ls",
    "pyright",
  })
end

return M
