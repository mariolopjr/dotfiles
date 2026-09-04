-- window layout helpers

local M = {}

-- equalizes the size of all the splits mainly for when switching from laptop to
-- plugged into monitor
function M.equalize()
  local tab = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabdo wincmd =")
  vim.api.nvim_set_current_tabpage(tab)
end

return M
