local M = {}

function M.setup()
  -- make line numbers default with relative numbers enabled
  vim.opt.number = true
  vim.opt.relativenumber = true

  vim.opt.mouse = 'a'

  vim.opt.showmode = false

  vim.schedule(function()
    vim.opt.clipboard = 'unnamedplus'
  end)

  -- enable modelines
  vim.opt.modeline = true
end

return M
-- vim: ts=2 sts=2 sw=2 et
