-- Lua development, lazydev for the nvim config

return {
  {
    -- configures lua_ls for the nvim config, runtime and plugins
    "folke/lazydev.nvim",
    -- lua.chezmoitmpl is chezmoi.vim's compound ft for lua template sources
    ft = { "lua", "lua.chezmoitmpl" },
    -- annotations only, never loaded at runtime
    dependencies = { "DrKJeff16/wezterm-types" },
    ---@type lazydev.Config
    opts = {
      library = {
        { plugins = { "nvim-dap-ui" }, types = true },
        { path = "lazydev.nvim", words = { "lazydev" } },
        { path = "snacks.nvim", words = { "Snacks" } },
        { path = "wezterm-types", mods = { "wezterm" } },
        -- Renoise tool API
        {
          path = vim.fs.normalize("~/.local/share/luals/renoise-definitions"),
          words = { "renoise" },
        },
        -- pattrns phrase scripts, trigger with a `-- pattrns` comment at the top
        {
          path = vim.fs.normalize(
            "~/.local/share/luals/pattrns-types/types/pattrns"
          ),
          words = { "pattrns" },
        },
      },
    },
  },
}
