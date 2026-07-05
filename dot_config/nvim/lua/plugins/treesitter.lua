local ensure_installed = {
  "bash",
  "c",
  "c_sharp",
  "diff",
  "fish",
  "gotmpl",
  "html",
  "just",
  "ledger",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "query",
  "rust",
  "ron",
}

-- filetypes that should keep their native indent instead of treesitter indent
-- use the filetype and not the parser name
local no_ts_indent = {
  ruby = true,
  cs = true,
}

-- treesitter aware motions, applied the same way in all four directions
local moves = {
  goto_next_start = {
    ["]f"] = "@function.outer",
    ["]c"] = "@class.outer",
    ["]a"] = "@parameter.inner",
  },
  goto_next_end = {
    ["]F"] = "@function.outer",
    ["]C"] = "@class.outer",
    ["]A"] = "@parameter.inner",
  },
  goto_previous_start = {
    ["[f"] = "@function.outer",
    ["[c"] = "@class.outer",
    ["[a"] = "@parameter.inner",
  },
  goto_previous_end = {
    ["[F"] = "@function.outer",
    ["[C"] = "@class.outer",
    ["[A"] = "@parameter.inner",
  },
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup()

      -- install any wanted parsers that are missing
      local have = {}
      for _, lang in ipairs(ts.get_installed("parsers")) do
        have[lang] = true
      end
      local missing = vim.tbl_filter(function(lang)
        return not have[lang]
      end, ensure_installed)
      if #missing > 0 then
        ts.install(missing):await(function() end)
      end

      -- installable parsers, looked up lazily so we only pay for it on a miss
      local available
      local installing = {}

      local function set_indent(buf, ft)
        if not no_ts_indent[ft] then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      -- start highlighting and indent per buffer, installing parsers on demand.
      -- neovim only auto starts treesitter for its few bundled languages, so we
      -- drive it here for everything else
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup(
          "treesitter_highlight",
          { clear = true }
        ),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not lang then
            return
          end

          if pcall(vim.treesitter.start, ev.buf, lang) then
            set_indent(ev.buf, ev.match)
            return
          end

          -- parser is not present, install it once then start
          available = available or ts.get_available()
          if installing[lang] or not vim.tbl_contains(available, lang) then
            return
          end
          installing[lang] = true
          ts.install(lang):await(function()
            installing[lang] = nil
            vim.schedule(function()
              if
                vim.api.nvim_buf_is_valid(ev.buf)
                and pcall(vim.treesitter.start, ev.buf, lang)
              then
                set_indent(ev.buf, ev.match)
              end
            end)
          end)
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = "VeryLazy",
    config = function()
      require("nvim-treesitter-textobjects").setup({
        move = { set_jumps = true },
      })

      local move = require("nvim-treesitter-textobjects.move")
      for fn, keys in pairs(moves) do
        for key, query in pairs(keys) do
          vim.keymap.set({ "n", "x", "o" }, key, function()
            -- in diff mode fall back to native change navigation for the class keys
            if vim.wo.diff and key:match("[cC]") then
              vim.cmd("normal! " .. key)
              return
            end
            move[fn](query, "textobjects")
          end, { silent = true, desc = "TS " .. query })
        end
      end
    end,
  },
}
