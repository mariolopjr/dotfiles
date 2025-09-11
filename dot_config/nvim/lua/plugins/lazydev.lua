---@module "lazydev"
return {
  { "justinsgithub/wezterm-types", lazy = true },
  { "LuaCATS/love2d", lazy = true },
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    "folke/lazydev.nvim",
    ft = "lua",
    ---@type lazydev.Config
    opts = {
      library = {
        { plugins = { "nvim-dap-ui" }, types = true },
        { path = "wezterm-types", mods = { "wezterm" } },
        { path = "love2d/library", words = { "love" } },
      },
    },
    init = function()
      vim.api.nvim_create_user_command("LoveRun", function(args)
        local love2d = require("love2d")
        local path = love2d.find_src_path(args.args)
        if path then
          love2d.run(path)
        else
          vim.notify("No main.lua file found", vim.log.levels.ERROR)
        end
      end, { nargs = "?", complete = "dir" })

      vim.api.nvim_create_user_command("LoveStop", function()
        local love2d = require("love2d")
        love2d.stop()
      end, {})
    end,
  },
}
