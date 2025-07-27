local M = {}

local icons = {
  [vim.diagnostic.severity.ERROR] = "",
  [vim.diagnostic.severity.WARN] = "",
  [vim.diagnostic.severity.HINT] = "",
  [vim.diagnostic.severity.INFO] = "",
}

M.setup = function()
  if vim.g.vscode then
    return
  end

  -- enable LSPs
  vim.lsp.enable({
    "clangd",
    "fish_lsp",
    "gopls",
    "lua_ls",
    "pyright",
  })

  -- setup inlay hints
  vim.lsp.inlay_hint.enable(true)

  -- setup inline diagnostics
  vim.diagnostic.config({
    underline = true,
    update_in_insert = false,
    virtual_text = {
      prefix = function(diagnostics)
        return icons[diagnostics.severity] or "●"
      end,
      spacing = 4,
      source = "if_many", -- show source if multiple
    },
    signs = icons,
    severity_sort = true,
  })
end

return M
