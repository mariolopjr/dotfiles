return {
  { -- collection of small independent plugin modules
    "echasnovski/mini.nvim",
    config = function()
      -- better around/inside textobjects
      --
      -- examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require("mini.ai").setup({ n_lines = 500 })

      -- add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require("mini.surround").setup()

      -- fast autopairs
      require("mini.pairs").setup()

      -- mini.pairs is not aware of snacks_picker_input (unlike TelescopePrompt/fzf)
      -- so disable it there to avoid interfering with backspace behavior
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "snacks_picker_input", "snacks_input" },
        callback = function()
          vim.b.minipairs_disable = true
        end,
      })

      -- session management, autoread restores .session.nvim when nvim is
      -- started without file arguments, autowrite only writes back sessions
      -- that were read so random directories are not littered with files
      require("mini.sessions").setup({
        autoread = true,
        autowrite = true,
        file = ".session.nvim",
      })

      -- icons
      require("mini.icons").setup({
        file = {
          [".chezmoiignore"] = { glyph = "", hl = "MiniIconsGrey" },
          [".chezmoiremove"] = { glyph = "", hl = "MiniIconsGrey" },
          [".chezmoiroot"] = { glyph = "", hl = "MiniIconsGrey" },
          [".chezmoiversion"] = { glyph = "", hl = "MiniIconsGrey" },
          ["bash.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["json.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["ps1.tmpl"] = { glyph = "󰨊", hl = "MiniIconsGrey" },
          ["sh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["toml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["yaml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
          ["zsh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
        },
      })

      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end

      -- statusline
      require("mini.statusline").setup()

      -- diff
      require("mini.diff").setup()
    end,
  },
}
