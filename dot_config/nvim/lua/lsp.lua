local M = {}

local icons = {
  [vim.diagnostic.severity.ERROR] = "",
  [vim.diagnostic.severity.WARN] = "",
  [vim.diagnostic.severity.HINT] = "",
  [vim.diagnostic.severity.INFO] = "",
}

M.setup = function()
  -- map :checkhealth vim.lsp
  vim.keymap.set(
    "n",
    "<leader>pl",
    ":checkhealth vim.lsp<CR>",
    { desc = "Check LSP health" }
  )

  -- configure jsonls
  vim.lsp.config("jsonls", {
    cmd = { "vscode-json-language-server", "--stdio" },
    init_options = {
      provideFormatter = false,
    },
    filetypes = { "json", "jsonc", "json5" },
    root_markers = { ".git" },
    settings = {
      json = {
        schemas = require("schemastore").json.schemas({
          select = {
            "GitHub Action",
            "GitHub Workflow",
            "JSON Resume",
          },
        }),
        validate = { enable = true },
      },
    },
  })

  -- enable LSPs
  vim.lsp.enable({
    "clangd",
    "fish_lsp",
    "gopls",
    "lua_ls",
    "marksman",
    "ty",
    "jsonls",
    -- "yamlls",
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
