-- C# development, mainly for Godot
-- the coreclr debug adapter is configured in plugins/dap.lua

return {
  {
    "seblyng/roslyn.nvim",
    ft = "cs",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {},
  },
}
