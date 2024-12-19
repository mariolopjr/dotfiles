local buf = vim.api.nvim_get_current_buf()

local map = function(keys, func, desc, mode)
  mode = mode or "n"
  vim.keymap.set(mode, keys, func, { buffer = buf, desc = "LSP: " .. desc })
end

-- code actions
-- map("<leader>ca", vim.cmd.RustLsp("codeAction"), "[C]ode [A]ction", { "n", "x" })

-- override hover
-- map("K", vim.cmd.RustLsp({ "hover", "actions" }), "[K] Hover")
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
