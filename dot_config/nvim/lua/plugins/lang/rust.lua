-- Rust development, keymaps live in after/ftplugin/rust.lua

return {
  {
    "mrcjkb/rustaceanvim",
    version = "^9",
    lazy = false,
    init = function()
      vim.g.rustaceanvim = {
        tools = {
          float_win_config = {
            border = "rounded",
            max_width = 90,
          },
        },
        server = {
          default_settings = {
            ["rust-analyzer"] = {
              hover = {
                memoryLayout = { niches = true },
                show = { traitAssocItems = 5 },
              },
            },
          },
        },
      }
    end,
  },
  {
    -- crate version hints in Cargo.toml
    "saecki/crates.nvim",
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    opts = {},
  },
}
