---@module "lazydev"
local luv = vim.loop
local handle = nil

local function find_src_path(arg)
  -- Simple logic: use arg if provided, else current directory
  local path = arg ~= "" and arg or vim.fn.getcwd()
  if vim.fn.filereadable(path .. "/main.lua") == 1 then
    return path
  end

  path = path .. "/game"
  if vim.fn.filereadable(path .. "/main.lua") == 1 then
    return path
  end
  return nil
end

local function love_run(path)
  if handle then
    vim.notify("LÖVE is already running", vim.log.levels.WARN)
    return
  end
  local love_bin = "love" -- assumes 'love' is in PATH
  handle = luv.spawn(love_bin, { args = { path } }, function(code, _)
    handle = nil
    if code ~= 0 then
      vim.notify("LÖVE exited with code " .. code, vim.log.levels.ERROR)
    end
  end)
  if handle then
    vim.notify("LÖVE started: " .. path, vim.log.levels.INFO)
  else
    vim.notify("Failed to start LÖVE", vim.log.levels.ERROR)
  end
end

local function love_stop()
  if handle then
    handle:kill("sigterm")
    handle = nil
    vim.notify("LÖVE stopped", vim.log.levels.INFO)
  else
    vim.notify("No LÖVE process running", vim.log.levels.WARN)
  end
end

return {
  { "justinsgithub/wezterm-types", lazy = true },
  { "LuaCATS/love2d", lazy = true },
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    "folke/lazydev.nvim",
    ft = "lua",
    ---@type lazydev.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      library = {
        { plugins = { "nvim-dap-ui" }, types = true },
        { path = "wezterm-types", mods = { "wezterm" } },
        { path = "love2d/library", words = { "love" } },
      },
    },
    keys = {
      { "<leader>rp", "<cmd>LoveRun<cr>", ft = "lua", desc = "Run LÖVE" },
      { "<leader>rs", "<cmd>LoveStop<cr>", ft = "lua", desc = "Stop LÖVE" },
    },
    init = function()
      vim.api.nvim_create_user_command("LoveRun", function(args)
        local path = find_src_path(args.args)
        if path then
          love_run(path)
        else
          vim.notify("No main.lua file found", vim.log.levels.ERROR)
        end
      end, { nargs = "?", complete = "dir" })

      vim.api.nvim_create_user_command("LoveStop", function()
        love_stop()
      end, {})
    end,
  },
}
