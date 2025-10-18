local bufnr = vim.api.nvim_get_current_buf()
local cargo = vim.loop
local cargo_handle = nil

local function cargo_run()
  if cargo_handle then
    vim.notify("cargo run is already running", vim.log.levels.WARN)
    return
  end
  local cargo_bin = "cargo"
  cargo_handle = cargo.spawn(
    cargo_bin,
    { args = { "run" }, cwd = vim.fn.getcwd() },
    function(code, _)
      cargo_handle = nil
      if code ~= 0 then
        vim.notify("cargo run exited with code " .. code, vim.log.levels.ERROR)
      else
        vim.notify("cargo run exited successfully", vim.log.levels.INFO)
      end
    end
  )
  if cargo_handle then
    vim.notify("cargo run started", vim.log.levels.INFO)
  else
    vim.notify("Failed to start cargo run", vim.log.levels.ERROR)
  end
end

local function cargo_stop()
  if cargo_handle then
    cargo_handle:kill("sigterm")
    cargo_handle = nil
    vim.notify("cargo run stopped", vim.log.levels.INFO)
  else
    vim.notify("No cargo run process running", vim.log.levels.WARN)
  end
end

vim.api.nvim_create_user_command("CargoRun", cargo_run, {})
vim.api.nvim_create_user_command("CargoStop", cargo_stop, {})

vim.keymap.set(
  "n",
  "<leader>rp",
  "<cmd>CargoRun<cr>",
  { buffer = true, desc = "[R]un [P]rogram Cargo Run" }
)
vim.keymap.set(
  "n",
  "<leader>rs",
  "<cmd>CargoStop<cr>",
  { buffer = true, desc = "[R]un [Stop] Cargo Run" }
)

vim.keymap.set("n", "<leader>ca", function()
  vim.cmd.RustLsp("codeAction") -- supports rust-analyzer's grouping
  -- or vim.lsp.buf.codeAction() if you don't want grouping.
end, { silent = true, buffer = bufnr, desc = "[C]ode [A]ction" })

vim.keymap.set(
  "n",
  "K", -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
  function()
    vim.cmd.RustLsp({ "hover", "actions" })
  end,
  { silent = true, buffer = bufnr }
)

vim.keymap.set("n", "<leader>rc", function()
  vim.cmd.RustLsp("openCargo")
end, { silent = true, buffer = bufnr, desc = "[R]un Open [Cargo] file" })
