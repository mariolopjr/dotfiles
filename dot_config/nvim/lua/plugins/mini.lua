return {
  { -- Collection of various small independent plugins/modules
    "echasnovski/mini.nvim",
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require("mini.ai").setup({ n_lines = 500 })

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require("mini.surround").setup()

      -- fast autopairs
      require("mini.pairs").setup()

      -- show notifications
      require("mini.notify").setup()

      -- dashboard
      require("mini.starter").setup()

      -- sessions management
      require("mini.sessions").setup()

      -- icons
      require("mini.icons").setup()

      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end

      -- statusline
      require("mini.statusline").setup()

      -- ident lines
      require("mini.indentscope").setup({
        symbol = "|",
      })

      -- git integration
      require("mini.diff").setup()
      require("mini.git").setup()

      -- snippets support
      -- TODO: actually load snippets
      require("mini.snippets").setup()

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
}
