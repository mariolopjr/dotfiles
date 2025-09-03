local M = {}

M.setup = function()
  -- install
  vim.pack.add({
    { src = "https://github.com/catppuccin/nvim" },
  })

  ---@type CatppuccinOptions
  local opts = {
    integrations = {
      blink_cmp = true,
      leap = true,
      markdown = true,
      mini = true,
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      neotest = true,
      treesitter = true,
      treesitter_context = true,
      which_key = true,
    },
  }

  -- setup
  require("catppuccin").setup(opts)
  vim.cmd.colorscheme("catppuccin-macchiato")
end

if vim.g.use_vim_pack then
  return M
end

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    init = function()
      vim.cmd.colorscheme("catppuccin-macchiato")
    end,
    opts = {
      integrations = {
        blink_cmp = true,
        leap = true,
        markdown = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        neotest = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
  },
}
