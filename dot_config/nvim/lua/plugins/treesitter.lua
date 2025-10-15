local function is_loaded(name)
  local config = require("lazy.core.config")
  return config.plugins[name] and config.plugins[name]._.loaded
end

local textobjects = {
  move = {
    enable = true,
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
  },
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    lazy = vim.fn.argc(-1) == 0,
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "diff",
        "fish",
        "gotmpl",
        "html",
        "just",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "query",
        "rust",
        "ron",
      },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { "ruby" },
      },
      indent = { enable = true, disable = { "ruby" } },
      textobjects = textobjects,
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    config = function()
      -- If treesitter is already loaded, we need to run config again for textobjects
      if is_loaded("nvim-treesitter") then
        require("nvim-treesitter.configs").setup({ textobjects = textobjects })
      end

      -- When in diff mode, we want to use the default
      -- vim text objects c & C instead of the treesitter ones.
      local move = require("nvim-treesitter.textobjects.move") ---@type table<string,fun(...)>
      local configs = require("nvim-treesitter.configs")
      for name, fn in pairs(move) do
        if name:find("goto") == 1 then
          move[name] = function(q, ...)
            if vim.wo.diff then
              local config = configs.get_module("textobjects.move")[name] ---@type table<string,string>
              for key, query in pairs(config or {}) do
                if q == query and key:find("[%]%[][cC]") then
                  vim.cmd("normal! " .. key)
                  return
                end
              end
            end
            return fn(q, ...)
          end
        end
      end
    end,
  },
}
