---@diagnostic disable: missing-fields
return {
  {
    "smoka7/hop.nvim",
    version = "*",
    opts = {
      keys = "etovxqpdygfblzhckisuran",
      uppercase_labels = true,
    },
    init = function()
      local hop = require("hop")
      local direction = require("hop.hint").HintDirection
      local map = vim.keymap.set

      -- sneak motions
      map({ "n", "v" }, "f", function()
        hop.hint_char2({ direction = direction.AFTER_CURSOR, current_line_only = true })
      end)

      map({ "n", "v" }, "F", function()
        hop.hint_char2({ direction = direction.BEFORE_CURSOR, current_line_only = true })
      end)

      map({ "n", "v" }, "t", function()
        hop.hint_char2({
          direction = direction.AFTER_CURSOR,
          current_line_only = true,
          hint_offset = -1,
        })
      end)

      map({ "n", "v" }, "T", function()
        hop.hint_char2({
          direction = direction.BEFORE_CURSOR,
          current_line_only = true,
          hint_offset = 1,
        })
      end)

      -- easymotion motions
      map({ "n", "v" }, "<leader><leader>w", function()
        hop.hint_words({ direction = direction.AFTER_CURSOR })
      end, { desc = "[ ] [ ] Hop to [W]ord After Cursor" })

      map({ "n", "v" }, "<leader><leader>b", function()
        hop.hint_words({ direction = direction.BEFORE_CURSOR })
      end, { desc = "[ ] [ ] Hop to Word [Before] Cursor" })

      map({ "n", "v" }, "<leader><leader>j", function()
        hop.hint_lines_skip_whitespace({ direction = direction.AFTER_CURSOR })
      end, { desc = "[ ] [ ] [j] Hop to Line After Cursor" })

      map({ "n", "v" }, "<leader><leader>k", function()
        hop.hint_lines_skip_whitespace({ direction = direction.BEFORE_CURSOR })
      end, { desc = "[ ] [ ] [k] Hop to Line Before Cursor" })
    end,
  },
}
