-- Re-apply mise's per-directory environment when Neovim's cwd changes

local M = {}

-- Directories that only fish adds to PATH, guaranteed here so tools like
-- roslyn-language-server resolve no matter which shell or GUI launched nvim
local function guaranteed_dirs()
  local home = vim.uv.os_homedir()
  return { home .. "/.dotnet/tools", home .. "/.local/bin" }
end

-- Prepend dirs to a PATH string, skipping any already present
local function with_dirs(path, dirs)
  local present = {}
  for entry in vim.gsplit(path or "", ":", { plain = true }) do
    present[entry] = true
  end
  local prefix = {}
  for _, dir in ipairs(dirs) do
    if not present[dir] then
      prefix[#prefix + 1] = dir
    end
  end
  if #prefix == 0 then
    return path
  end
  return table.concat(prefix, ":") .. ":" .. path
end

function M.setup()
  local mise = vim.fn.exepath("mise")
  if mise == "" then
    mise = "/opt/homebrew/bin/mise"
  end
  if vim.fn.executable(mise) ~= 1 then
    return
  end

  -- base env
  local base = vim.fn.environ()
  base.PATH = with_dirs(base.PATH, guaranteed_dirs())

  local applied = {}
  local last_dir

  local function reload(dir)
    dir = dir or vim.fn.getcwd()
    if dir == last_dir then
      return
    end
    last_dir = dir

    local res = vim
      .system(
        { mise, "env", "-J", "-C", dir },
        { clear_env = true, env = base, text = true }
      )
      :wait()
    if res.code ~= 0 then
      return
    end
    local ok, env = pcall(vim.json.decode, res.stdout)
    if not ok or type(env) ~= "table" then
      return
    end

    local fresh = {}
    for key, value in pairs(env) do
      vim.env[key] = value
      fresh[key] = true
    end
    -- drop vars a previous project set that this one does not, restoring the
    -- base value (nil when the base never had it)
    for key in pairs(applied) do
      if not fresh[key] then
        vim.env[key] = base[key]
      end
    end
    applied = fresh
  end

  local group = vim.api.nvim_create_augroup("mise_env", { clear = true })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      reload(vim.v.event.cwd)
    end,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      reload()
    end,
  })

  -- cover the startup cwd before the first LSP attaches
  reload()
end

return M
