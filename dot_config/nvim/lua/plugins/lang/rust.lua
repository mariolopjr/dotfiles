-- Rust development, keymaps live in after/ftplugin/rust.lua

return {
  {
    "mrcjkb/rustaceanvim",
    version = "^6",
    lazy = false,
  },
  {
    -- crate version hints in Cargo.toml
    "saecki/crates.nvim",
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    opts = {},
  },
}
