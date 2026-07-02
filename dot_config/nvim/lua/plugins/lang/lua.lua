-- Lua development, lazydev for the nvim config plus LÖVE support

local function find_love_path(arg)
  -- use arg if provided, else the current directory
  local path = arg ~= "" and arg or vim.fn.getcwd()
  if vim.fn.filereadable(path .. "/main.lua") == 1 then
    return path
  end

  path = path .. "/src"
  if vim.fn.filereadable(path .. "/main.lua") == 1 then
    return path
  end
end

return {
  { "justinsgithub/wezterm-types", lazy = true },
  { "LuaCATS/love2d", lazy = true },
  {
    -- configures lua_ls for the nvim config, runtime and plugins
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
      local love = require("util.proc").get("LÖVE")

      vim.api.nvim_create_user_command("LoveRun", function(args)
        local path = find_love_path(args.args)
        if path then
          love.start("love", { path })
        else
          vim.notify("No main.lua file found", vim.log.levels.ERROR)
        end
      end, { nargs = "?", complete = "dir" })

      vim.api.nvim_create_user_command("LoveStop", love.stop, {})
    end,
  },
}
