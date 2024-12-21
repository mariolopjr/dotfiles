return {
  {
    "smoka7/hop.nvim",
    version = "*",
    opts = {
      keys = "etovxqpdygfblzhckisuran",
    },
    init = function()
      local hop = require("hop")
      local directions = require("hop.hint").HintDirection
      local map = vim.keymap.set

      -- sneak motions
      map({ "n", "v" }, "f", function()
        hop.hint_char2({ direction = directions.AFTER_CURSOR, current_line_only = true })
      end, { remap = true })

      map({ "n", "v" }, "F", function()
        hop.hint_char2({ direction = directions.BEFORE_CURSOR, current_line_only = true })
      end, { remap = true })

      map({ "n", "v" }, "t", function()
        hop.hint_char2({
          direction = directions.AFTER_CURSOR,
          current_line_only = true,
          hint_offset = -1,
        })
      end, { remap = true })

      map({ "n", "v" }, "T", function()
        hop.hint_char2({
          direction = directions.BEFORE_CURSOR,
          current_line_only = true,
          hint_offset = 1,
        })
      end, { remap = true })

      -- easymotion motions
      map({ "n", "v" }, "<Leader><Leader>w", function()
        hop.hint_words({ direction = directions.AFTER_CURSOR })
      end, { remap = true })

      map({ "n", "v" }, "<Leader><Leader>b", function()
        hop.hint_words({ direction = directions.BEFORE_CURSOR })
      end, { remap = true })

      map({ "n", "v" }, "<Leader><Leader>j", function()
        hop.hint_lines_skip_whitespace({ direction = directions.AFTER_CURSOR })
      end, { remap = true })

      map({ "n", "v" }, "<Leader><Leader>k", function()
        hop.hint_lines_skip_whitespace({ direction = directions.BEFORE_CURSOR })
      end, { remap = true })
    end,
  },
}
