-- Lua development, lazydev for the nvim config

return {
  {
    -- configures lua_ls for the nvim config, runtime and plugins
    "folke/lazydev.nvim",
    ft = "lua",
    ---@type lazydev.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      library = {
        { plugins = { "nvim-dap-ui" }, types = true },
      },
    },
  },
}
