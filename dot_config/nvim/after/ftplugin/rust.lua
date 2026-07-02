local bufnr = vim.api.nvim_get_current_buf()
local cargo = require("util.proc").get("cargo run")

vim.api.nvim_create_user_command("CargoRun", function()
  cargo.start("cargo", { "run" }, vim.fn.getcwd())
end, {})

vim.api.nvim_create_user_command("CargoStop", cargo.stop, {})

vim.keymap.set(
  "n",
  "<leader>rp",
  "<cmd>CargoRun<cr>",
  { buffer = bufnr, desc = "[R]un [P]rogram Cargo Run" }
)
vim.keymap.set(
  "n",
  "<leader>rs",
  "<cmd>CargoStop<cr>",
  { buffer = bufnr, desc = "[R]un [S]top Cargo Run" }
)

vim.keymap.set("n", "<leader>ca", function()
  vim.cmd.RustLsp("codeAction") -- supports rust-analyzer's grouping
end, { silent = true, buffer = bufnr, desc = "[C]ode [A]ction" })

-- override the built-in hover keymap with rustaceanvim's hover actions
vim.keymap.set("n", "K", function()
  vim.cmd.RustLsp({ "hover", "actions" })
end, { silent = true, buffer = bufnr })

vim.keymap.set("n", "<leader>rc", function()
  vim.cmd.RustLsp("openCargo")
end, { silent = true, buffer = bufnr, desc = "[R]un Open [C]argo file" })
