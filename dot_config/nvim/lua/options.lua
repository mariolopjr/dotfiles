local M = {}

function M.setup()
  -- make line numbers default with relative numbers enabled
  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.mouse = "a"
  vim.opt.showmode = false
  vim.opt.cursorline = true

  vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
  end)

  -- enable modelines
  vim.opt.modeline = true
end

return M
