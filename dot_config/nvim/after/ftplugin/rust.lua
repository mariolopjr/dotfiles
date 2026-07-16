local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set("n", "<leader>ca", function()
  vim.cmd.RustLsp("codeAction") -- supports rust-analyzer's grouping
end, { silent = true, buffer = bufnr, desc = "[C]ode [A]ction" })

-- override the built-in hover keymap with rustaceanvim's hover actions
vim.keymap.set("n", "K", function()
  vim.cmd.RustLsp({ "hover", "actions" })
end, { silent = true, buffer = bufnr })
