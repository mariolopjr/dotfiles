---@module "lazydev"
return {
  { "justinsgithub/wezterm-types", lazy = true },
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    "folke/lazydev.nvim",
    ft = "lua",
    ---@type lazydev.Config
    opts = {
      library = {
        -- { path = "love2d/library", words = { "love" } },
        { plugins = { "nvim-dap-ui" }, types = true },
        { path = "wezterm-types", mods = { "wezterm" } },
      },
    },
  },
  -- love2d types
  -- { "LuaCATS/love2d", lazy = true },
}
