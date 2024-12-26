local buf = vim.api.nvim_get_current_buf()

-- code actions
-- map("<leader>ca", vim.cmd.RustLsp("codeAction"), "[C]ode [A]ction", { "n", "x" })

-- override hover
-- map("K", vim.cmd.RustLsp({ "hover", "actions" }), "[K] Hover")

-- check if not in vscode
if not vim.g.vscode then
  vim.keymap.set("n", "<leader>a", function()
    vim.cmd.RustLsp("codeAction") -- supports rust-analyzer's grouping
    -- or vim.lsp.buf.codeAction() if you don't want grouping.
  end, { silent = true, buffer = buf })
  vim.keymap.set(
    "n",
    "K", -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
    function()
      vim.cmd.RustLsp({ "hover", "actions" })
    end,
    { silent = true, buffer = buf }
  )
end
