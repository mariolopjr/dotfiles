local icons = {
  [vim.diagnostic.severity.ERROR] = "",
  [vim.diagnostic.severity.WARN] = "",
  [vim.diagnostic.severity.HINT] = "",
  [vim.diagnostic.severity.INFO] = "",
}

--- @param fn string A function name in util.lsp
--- @return fun()
local function lsp(fn)
  return function()
    require("util.lsp")[fn]()
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    event = "LazyFile",
    dependencies = {
      "b0o/schemastore.nvim",
    },
    -- lspconfig leaves :LspRestart undefined here because core owns :lsp
    init = function()
      vim.api.nvim_create_user_command("LspRestart", lsp("restart"), {
        desc = "Restart project LSP clients",
      })
    end,
    keys = {
      { "<leader>lr", lsp("restart"), desc = "[R]estart LSP" },
      { "<leader>ls", lsp("stop"), desc = "[S]top LSP" },
      { "<leader>le", lsp("enable"), desc = "[E]nable LSP" },
      { "<leader>ll", lsp("log"), desc = "LSP [L]og" },
      { "<leader>li", "<cmd>checkhealth vim.lsp<CR>", desc = "LSP [I]nfo" },
    },
    config = function()
      vim.diagnostic.config({
        underline = true,
        update_in_insert = false,
        float = { border = "rounded" },
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

      -- chezmoi.vim gives lua template sources the compound filetype lua.chezmoitmpl
      vim.lsp.config("lua_ls", {
        filetypes = { "lua", "lua.chezmoitmpl" },
      })

      vim.lsp.enable({
        "clangd",
        "codebook",
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
