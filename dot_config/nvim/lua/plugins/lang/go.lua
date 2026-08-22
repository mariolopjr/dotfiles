-- Go development

local go = require("util.go")

vim.lsp.config("gopls", {
  cmd = { go.exe("gopls") or "gopls" },
  -- go.work covers a multi-module workspace and go.mod a single one
  root_markers = { "go.work", "go.mod", ".git" },
  settings = {
    gopls = {
      -- the engine bindings are behind cgo
      env = { CGO_ENABLED = "1" },

      staticcheck = true,
      vulncheck = "Imports",
      analyses = {
        shadow = true,
        appendclipped = true,
        slicesdelete = true,
        fieldalignment = true,
      },

      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
        -- marks a call whose error result is dropped
        ignoredError = true,
      },

      codelenses = {
        generate = true,
        test = true,
        tidy = true,
        upgrade_dependency = true,
        vendor = true,
        run_govulncheck = true,
        regenerate_cgo = true,
      },

      symbolScope = "all",
      symbolMatcher = "FastFuzzy",

      hoverKind = "FullDocumentation",
      linkTarget = "pkg.go.dev",

      renameMovesSubpackages = true,
      moveType = true,

      usePlaceholders = true,
      completionBudget = "100ms",
      matcher = "Fuzzy",
      gofumpt = true,
      semanticTokens = true,

      directoryFilters = {
        "-**/node_modules",
        "-**/vendor",
        "-**/.godot",
      },
    },
  },
})

vim.api.nvim_create_user_command("GoInfo", function()
  vim.notify(table.concat(go.report(), "\n"))
end, {
  desc = "Report the go module and tools resolved for this buffer",
})

return {}
