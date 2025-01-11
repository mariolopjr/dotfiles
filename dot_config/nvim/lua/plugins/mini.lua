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

      -- sessions management
      require("mini.sessions").setup()

      -- icons
      require("mini.icons").setup({
        file = {
          [".chezmoiignore"] = { glyph = "", hl = "MiniIconsGrey" },
          [".chezmoiremove"] = { glyph = "", hl = "MiniIconsGrey" },
          [".chezmoiroot"] = { glyph = "", hl = "MiniIconsGrey" },
          [".chezmoiversion"] = { glyph = "", hl = "MiniIconsGrey" },
          ["bash.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["json.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["ps1.tmpl"] = { glyph = "󰨊", hl = "MiniIconsGrey" },
          ["sh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["toml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["yaml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["zsh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
        },
      })

      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end

      -- statusline
      require("mini.statusline").setup()

      -- snippets support
      -- TODO: actually load snippets
      require("mini.snippets").setup()

      -- diff
      require("mini.diff").setup()

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
}
