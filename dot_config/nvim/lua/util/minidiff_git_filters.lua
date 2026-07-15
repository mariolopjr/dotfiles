-- mini.diff source for files git stores through a clean/smudge filter (the
-- age-encrypted files)

local M = {}

local cache = {}

--- @param cwd string
--- @param args string[]
--- @return string|nil
local function git(cwd, args)
  local out = vim
    .system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true })
    :wait()
  if out.code ~= 0 then
    return nil
  end
  return vim.trim(out.stdout or "")
end

--- Whether git applies a clean/smudge filter to this path
--- @param cwd string
--- @param basename string
--- @return boolean
local function has_filter(cwd, basename)
  local out = git(cwd, { "check-attr", "filter", "--", basename })
  if out == nil then
    return false
  end
  local value = out:match(": filter: (.+)$")
  return value ~= nil and value ~= "unspecified" and value ~= "unset"
end

--- @param buf_id integer
local function set_ref(buf_id)
  if not vim.api.nvim_buf_is_valid(buf_id) then
    return
  end
  local path = vim.api.nvim_buf_get_name(buf_id)
  if path == "" then
    return
  end
  local cwd = vim.fn.fnamemodify(path, ":h")
  local basename = vim.fn.fnamemodify(path, ":t")

  vim.system(
    { "git", "cat-file", "--filters", ":0:./" .. basename },
    { cwd = cwd, text = true },
    vim.schedule_wrap(function(out)
      if not vim.api.nvim_buf_is_valid(buf_id) then
        return
      end
      -- not in the index (new or ignored file): unset, as the builtin source does
      if out.code ~= 0 or out.stdout == nil or out.stdout == "" then
        pcall(MiniDiff.set_ref_text, buf_id, {})
        return
      end
      pcall(MiniDiff.set_ref_text, buf_id, (out.stdout:gsub("\r\n", "\n")))
    end)
  )
end

M.source = {
  name = "git-filters",

  --- @param buf_id integer
  --- @return boolean
  attach = function(buf_id)
    local path = vim.api.nvim_buf_get_name(buf_id)
    if path == "" or vim.fn.filereadable(path) ~= 1 then
      return false
    end
    local cwd = vim.fn.fnamemodify(path, ":h")

    local git_dir =
      git(cwd, { "rev-parse", "--path-format=absolute", "--git-dir" })
    if git_dir == nil then
      return false
    end
    -- unfiltered path: let the builtin git source have it
    if not has_filter(cwd, vim.fn.fnamemodify(path, ":t")) then
      return false
    end

    set_ref(buf_id)

    -- re-read the reference when the index changes (commit, stage, checkout)
    local watcher, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
    if watcher == nil or timer == nil then
      return true
    end
    cache[buf_id] = { watcher = watcher, timer = timer }
    watcher:start(git_dir, {}, function(_, filename)
      if filename ~= "index" then
        return
      end
      -- debounce: git writes index.lock and renames it, sending several events
      timer:stop()
      timer:start(
        50,
        0,
        vim.schedule_wrap(function()
          set_ref(buf_id)
        end)
      )
    end)
    return true
  end,

  --- @param buf_id integer
  detach = function(buf_id)
    local c = cache[buf_id]
    if c == nil then
      return
    end
    pcall(function()
      c.watcher:stop()
    end)
    pcall(function()
      c.timer:stop()
    end)
    cache[buf_id] = nil
  end,
}

return M
