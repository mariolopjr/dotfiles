return {
  {
    -- interactive markdown todo lists, activates on TODO.md, todo.md and
    -- *.todo.md by default and saves plain gfm checkboxes to disk
    "bngarren/checkmate.nvim",
    version = "*",
    ft = "markdown",
    -- checkmate's own maps default to <leader>T*, which collides with the
    -- Tests menu, rebind them onto <leader>x
    opts = function()
      local defaults = require("checkmate.config").get_defaults()
      local keys = {}
      for lhs, spec in pairs(defaults.keys) do
        keys[(lhs:gsub("^<leader>T", "<leader>x"))] = spec
      end
      local metadata = defaults.metadata
      for _, meta in pairs(metadata) do
        local key = meta.key
        if type(key) == "string" then
          meta.key = key:gsub("^<leader>T", "<leader>x")
        end
      end
      return { keys = keys, metadata = metadata }
    end,
    -- global entry points, the in-buffer todo keymaps are checkmate's own
    -- buffer local <leader>x* set
    keys = {
      {
        "<leader>xo",
        function()
          require("util.todo").open()
        end,
        desc = "Open project TODO",
      },
      {
        "<leader>xi",
        function()
          require("util.todo").add()
        end,
        desc = "Add to project TODO",
      },
      {
        "<leader>xg",
        function()
          require("util.todo").grep()
        end,
        desc = "Grep project TODOs",
      },
      {
        "<leader>xG",
        function()
          require("util.todo").grep_all()
        end,
        desc = "Grep all project TODOs",
      },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = function(_, opts)
      local prev = opts.ignore
      opts.ignore = function(buf)
        if prev and prev(buf) then
          return true
        end
        local base = vim.fs.basename(vim.api.nvim_buf_get_name(buf))
        return base == "todo"
          or base == "TODO"
          or base == "todo.md"
          or base == "TODO.md"
          or base:match("%.todo$") ~= nil
          or base:match("%.todo%.md$") ~= nil
      end
    end,
  },
}
