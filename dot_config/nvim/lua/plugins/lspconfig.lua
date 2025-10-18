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
    opts = function()
      ---@class PluginLspOpts
      local ret = {
        ---@type vim.diagnostic.Opts
        diagnostics = {
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
        },
        inlay_hints = {
          enabled = true,
          exclude = {},
        },
        codelens = {
          enabled = true,
        },
        folds = {
          enabled = true,
        },
        capabilities = {
          workspace = {
            fileOperations = {
              didRename = true,
              willRename = true,
            },
          },
        },
        -- LSP Server Settings
        servers = {
          jsonls = {
            settings = {
              json = {
                schemas = require("schemastore").json.schemas({
                  select = {
                    "JSON Resume",
                  },
                }),
                validate = { enable = true },
              },
            },
          },
          yamlls = {

            settings = {
              yaml = {
                schemaStore = {
                  enable = false,
                  url = "",
                },
                schemas = require("schemastore").json.schemas({
                  select = {
                    "GitHub Action",
                    "GitHub Workflow",
                  },
                }),
              },
            },
          },
        },
      }
      return ret
    end,
    ---@param opts PluginLspOpts
    config = vim.schedule_wrap(function(_, opts)
      vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

      for server, sopts in pairs(opts.servers) do
        vim.lsp.config(server, sopts)
      end

      vim.lsp.enable({
        "clangd",
        "fish_lsp",
        "gopls",
        "lua_ls",
        "marksman",
        "ty",
        "jsonls",
        "yamlls",
      })
    end),
    keys = {
      {
        "<leader>pl",
        ":checkhealth vim.lsp<CR>",
        desc = "Check LSP health",
      },
    },
  },
}
