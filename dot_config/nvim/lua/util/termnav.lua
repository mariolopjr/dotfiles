-- Terminal-mode split navigation for the floating terminals

local M = {}

local MOVES = {
  h = "move_cursor_left",
  j = "move_cursor_down",
  k = "move_cursor_up",
  l = "move_cursor_right",
}

--- Map Ctrl+hjkl in terminal mode for a single buffer
--- @param buf integer
function M.attach(buf)
  for key, fn in pairs(MOVES) do
    vim.keymap.set("t", "<C-" .. key .. ">", function()
      local from = vim.api.nvim_get_current_win()
      require("smart-splits")[fn]()
      if vim.api.nvim_get_current_win() == from then
        vim.cmd.startinsert()
      end
    end, { buffer = buf, desc = "Move to " .. key .. " split" })
  end
end

return M
