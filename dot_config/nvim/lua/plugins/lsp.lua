local icons = {
  [vim.diagnostic.severity.ERROR] = "",
  [vim.diagnostic.severity.WARN] = "",
  [vim.diagnostic.severity.HINT] = "",
  [vim.diagnostic.severity.INFO] = "",
}

return {
  {
    "neovim/nvim-lspconfig",
    event = "LazyFile",
    dependencies = {
      "b0o/schemastore.nvim",
    },
    keys = {
      {
        "<leader>pl",
        ":checkhealth vim.lsp<CR>",
        desc = "Check LSP health",
      },
    },
    config = function()
      vim.diagnostic.config({
        underline = true,
        update_in_insert = false,
        virtual_text = {
          prefix = function(diagnostic)
            return icons[diagnostic.severity] or "●"
          end,
          spacing = 4,
          source = "if_many", -- show source if multiple
        },
        signs = { text = icons },
        severity_sort = true,
      })

      -- rename-aware workspace file operations for every server
      vim.lsp.config("*", {
        capabilities = {
          workspace = {
            fileOperations = {
              didRename = true,
              willRename = true,
            },
          },
        },
      })

      vim.lsp.config("jsonls", {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas({
              select = { "JSON Resume" },
            }),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            schemaStore = { enable = false, url = "" },
            schemas = require("schemastore").json.schemas({
              select = { "GitHub Action", "GitHub Workflow" },
            }),
          },
        },
      })

      vim.lsp.config("qlab_lsp", {
        cmd = { "qlab-lsp" }, -- on PATH via ~/.local/bin/qlab-lsp
        filetypes = { "ledger" },
        root_markers = { "main.ledger", ".git" },
      })

      vim.lsp.enable({
        "clangd",
        "fish_lsp",
        "gopls",
        "jsonls",
        "just",
        "lua_ls",
        "marksman",
        "nixd",
        "qlab_lsp",
        "ty",
        "yamlls",
        "zls",
      })
    end,
  },
}
