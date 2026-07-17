local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set("n", "<leader>ca", function()
  vim.cmd.RustLsp("codeAction") -- supports rust-analyzer's grouping
end, { silent = true, buffer = bufnr, desc = "[C]ode [A]ction" })

-- override the built-in hover keymap with rustaceanvim's hover actions
vim.keymap.set("n", "K", function()
  vim.cmd.RustLsp({ "hover", "actions" })
end, { silent = true, buffer = bufnr })

vim.keymap.set("n", "<leader>cm", function()
  vim.cmd.RustLsp("expandMacro")
end, { silent = true, buffer = bufnr, desc = "[C]ode expand [M]acro" })

vim.keymap.set("n", "<leader>cM", function()
  vim.cmd.RustLsp("rebuildProcMacros")
end, { silent = true, buffer = bufnr, desc = "[C]ode rebuild proc [M]acros" })

vim.keymap.set("n", "<leader>ce", function()
  vim.cmd.RustLsp("explainError")
end, { silent = true, buffer = bufnr, desc = "[C]ode [E]xplain error" })

vim.keymap.set("n", "<leader>cd", function()
  vim.cmd.RustLsp("renderDiagnostic")
end, { silent = true, buffer = bufnr, desc = "[C]ode rendered [D]iagnostic" })

vim.keymap.set("n", "<leader>co", function()
  vim.cmd.RustLsp("openDocs")
end, { silent = true, buffer = bufnr, desc = "[C]ode [O]pen docs.rs" })

vim.keymap.set("n", "<leader>cO", function()
  vim.cmd.RustLsp("parentModule")
end, { silent = true, buffer = bufnr, desc = "[C]ode Parent m[O]dule" })

-- background executor, failures land as diagnostics at the assertion site
vim.keymap.set("n", "<leader>ct", function()
  vim.cmd.RustLsp("testables")
end, { silent = true, buffer = bufnr, desc = "[C]ode [T]estables" })

vim.keymap.set("n", "<leader>dd", function()
  vim.cmd.RustLsp("debuggables")
end, { silent = true, buffer = bufnr, desc = "[D]ebug [D]ebuggables" })

vim.keymap.set("n", "<leader>ci", function()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
end, { silent = true, buffer = bufnr, desc = "[C]ode toggle [I]nlay hints" })

vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run, {
  silent = true,
  buffer = bufnr,
  desc = "[C]ode [L]ens run",
})

-- the capability provider tracks attach and refresh itself, no autocmds needed
vim.lsp.codelens.enable(true, { bufnr = bufnr })
