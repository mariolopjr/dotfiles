-- highlight when yanking text, try it with yap in normal mode
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- save the buffer when leaving it or when nvim loses focus
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  desc = "Autosave modified buffers",
  group = vim.api.nvim_create_augroup("autosave", { clear = true }),
  callback = function()
    if
      vim.bo.modified
      and not vim.bo.readonly
      and vim.bo.buftype == ""
      and vim.api.nvim_buf_get_name(0) ~= ""
    then
      vim.cmd("silent! update")
    end
  end,
})
