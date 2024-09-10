local M = {}

function M.setup()
  -- Make line numbers default with relative numbers enabled
  vim.opt.number = true
  vim.opt.relativenumber = true
end

return M
-- vim: ts=2 sts=2 sw=2 et
