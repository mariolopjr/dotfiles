-- Source a project's `.nvim.lua` when Neovim's cwd changes, not just at startup.

local M = {}

-- Checked in the cwd in this order, first readable one wins, matching the
-- precedence of Neovim's built-in exrc
local candidates = { ".nvim.lua", ".nvimrc", ".exrc" }

local function find(dir)
  for _, name in ipairs(candidates) do
    local path = dir .. "/" .. name
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end
end

local function source(path)
  -- routes through the trust database, prompts once for an untrusted file,
  -- returns nil when denied or unreadable
  local contents = vim.secure.read(path)
  if not contents then
    return
  end
  if path:sub(-4) == ".lua" then
    local chunk, err = load(contents, "@" .. path)
    if not chunk then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    local ok, res = pcall(chunk)
    if not ok then
      vim.notify(tostring(res), vim.log.levels.ERROR)
    end
  else
    local ok, res = pcall(vim.api.nvim_exec2, contents, {})
    if not ok then
      vim.notify(tostring(res), vim.log.levels.ERROR)
    end
  end
end

function M.setup()
  local last_dir

  local function load(dir)
    if dir == last_dir then
      return
    end
    last_dir = dir
    local path = find(dir)
    if path then
      source(path)
    end
  end

  local group = vim.api.nvim_create_augroup("exrc", { clear = true })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      load(vim.v.event.cwd)
    end,
  })
end

return M
