-- Lua development, lazydev for the nvim config

return {
  {
    -- configures lua_ls for the nvim config, runtime and plugins
    "folke/lazydev.nvim",
    -- lua.chezmoitmpl is chezmoi.vim's compound ft for lua template sources
    ft = { "lua", "lua.chezmoitmpl" },
    ---@type lazydev.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      library = {
        { plugins = { "nvim-dap-ui" }, types = true },
        { path = "snacks.nvim", words = { "Snacks" } },
      },
    },
  },
}
