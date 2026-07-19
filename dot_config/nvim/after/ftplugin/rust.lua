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

vim.keymap.set("n", "<leader>cR", function()
  vim.cmd.RustLsp("runnables")
end, { silent = true, buffer = bufnr, desc = "[C]ode [R]unnables" })

vim.keymap.set(
  "n",
  "<leader>cs",
  function()
    vim.cmd.RustLsp("ssr")
  end,
  { silent = true, buffer = bufnr, desc = "[C]ode [S]tructural search replace" }
)

vim.keymap.set("n", "<leader>ck", function()
  vim.cmd.RustLsp({ "moveItem", "up" })
end, { silent = true, buffer = bufnr, desc = "[C]ode move item up" })

vim.keymap.set("n", "<leader>cj", function()
  vim.cmd.RustLsp({ "moveItem", "down" })
end, { silent = true, buffer = bufnr, desc = "[C]ode move item down" })

vim.keymap.set("n", "<leader>cT", function()
  vim.cmd.RustLsp("relatedTests")
end, { silent = true, buffer = bufnr, desc = "[C]ode related [T]ests" })

vim.keymap.set("n", "<leader>cc", function()
  vim.cmd.RustLsp("openCargo")
end, { silent = true, buffer = bufnr, desc = "[C]ode open [C]argo.toml" })

vim.keymap.set("n", "<leader>cC", function()
  vim.cmd.RustLsp("flyCheck")
end, { silent = true, buffer = bufnr, desc = "[C]ode cargo [C]heck" })

vim.keymap.set("n", "<leader>cJ", function()
  vim.cmd.RustLsp("joinLines")
end, { silent = true, buffer = bufnr, desc = "[C]ode [J]oin lines" })

vim.keymap.set("n", "<leader>cS", function()
  vim.cmd.RustLsp("syntaxTree")
end, { silent = true, buffer = bufnr, desc = "[C]ode [S]yntax tree" })

vim.keymap.set("n", "<leader>cvm", function()
  vim.cmd.RustLsp({ "view", "mir" })
end, { silent = true, buffer = bufnr, desc = "[C]ode [v]iew [m]ir" })

vim.keymap.set("n", "<leader>cvh", function()
  vim.cmd.RustLsp({ "view", "hir" })
end, { silent = true, buffer = bufnr, desc = "[C]ode [v]iew [h]ir" })

vim.keymap.set("n", "<leader>cg", function()
  -- rustaceanvim renders the graph through graphviz
  if vim.fn.executable("dot") == 0 then
    vim.notify("crateGraph needs graphviz (dot) on PATH", vim.log.levels.WARN)
    return
  end
  vim.cmd.RustLsp("crateGraph")
end, { silent = true, buffer = bufnr, desc = "[C]ode crate [G]raph" })

vim.keymap.set("n", "<leader>cw", function()
  vim.cmd.RustLsp("reloadWorkspace")
end, { silent = true, buffer = bufnr, desc = "[C]ode reload [W]orkspace" })

-- re-run the last runnable without the picker
vim.keymap.set("n", "<leader>c.", function()
  vim.cmd.RustLsp("run")
end, { silent = true, buffer = bufnr, desc = "[C]ode run last runnable" })

vim.keymap.set("n", "<leader>ci", function()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
end, { silent = true, buffer = bufnr, desc = "[C]ode toggle [I]nlay hints" })

vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run, {
  silent = true,
  buffer = bufnr,
  desc = "[C]ode [L]ens run",
})

-- whole-workspace clippy/check into the quickfix list
vim.keymap.set("n", "<leader>cq", function()
  require("util.cargo_qf").run("clippy")
end, { silent = true, buffer = bufnr, desc = "[C]ode clippy [Q]uickfix" })

vim.keymap.set("n", "<leader>cQ", function()
  require("util.cargo_qf").run("check")
end, { silent = true, buffer = bufnr, desc = "[C]ode check [Q]uickfix" })

-- the capability provider tracks attach and refresh itself, no autocmds needed
vim.lsp.codelens.enable(true, { bufnr = bufnr })

-- markdown_inline is injected into doc comments in after/queries/rust/injections.scm
-- so intra-doc links like [`parse`] display as their link text. an empty
-- concealcursor reveals the full markup whenever the cursor is on that line
vim.opt_local.conceallevel = 2
vim.opt_local.concealcursor = ""
