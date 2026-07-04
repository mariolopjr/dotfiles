-- highlight when yanking text, try it with yap in normal mode
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- ensure a real file buffer always ends up with a filetype, both treesitter
-- and LSP gate on the FileType event, and some load paths skip detection
vim.api.nvim_create_autocmd("BufWinEnter", {
  desc = "Re-run filetype detection on file buffers that loaded without it",
  group = vim.api.nvim_create_augroup("ensure-filetype", { clear = true }),
  callback = function(ev)
    if
      vim.bo[ev.buf].filetype == ""
      and vim.bo[ev.buf].buftype == ""
      and not vim.b[ev.buf].tried_filetype_detect
      and vim.api.nvim_buf_get_name(ev.buf) ~= ""
    then
      vim.b[ev.buf].tried_filetype_detect = true
      vim.cmd("filetype detect")
    end
  end,
})

-- report neovim's cwd to the terminal via OSC 7
-- wezterm uses this for the tab name, and new panes
-- will also open in that directory
vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
  desc = "Emit OSC 7 with the current working directory",
  group = vim.api.nvim_create_augroup("osc7-cwd", { clear = true }),
  callback = function()
    local cwd = vim.uv.cwd()
    if not cwd then
      return
    end
    local host = vim.uv.os_gethostname() or ""
    local path = cwd:gsub("([^%w/._~-])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
    io.write(("\027]7;file://%s%s\027\\"):format(host, path))
    io.flush()
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
