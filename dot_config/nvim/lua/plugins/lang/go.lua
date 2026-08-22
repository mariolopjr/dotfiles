-- Go development

local go = require("util.go")

vim.lsp.config("gopls", {
  cmd = { go.exe("gopls") or "gopls" },
  settings = {
    gopls = {
      staticcheck = true,
      vulncheck = "Imports",
      analyses = {
        shadow = true,
        appendclipped = true,
        slicesdelete = true,
        fieldalignment = true,
      },

      -- gopls sends no hints unless each type of hint is configured
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

      -- the only lens gopls has disabled
      codelenses = {
        test = true,
      },

      renameMovesSubpackages = true,
      moveType = true,
      usePlaceholders = true,
    },
  },
})

vim.api.nvim_create_user_command("GoInfo", function()
  vim.notify(table.concat(go.report(), "\n"))
end, {
  desc = "Report the go module and tools resolved for this buffer",
})

return {}
