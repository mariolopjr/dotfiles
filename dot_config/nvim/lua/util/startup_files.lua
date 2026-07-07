-- Track files opened directly on the command line (nvim file.txt)

local M = {}

local store = vim.fn.stdpath("state") .. "/startup_files.json"
local max = 30

--- ephemeral files that should never enter the list even when passed as args
--- @param path string absolute path
--- @return boolean
local function excluded(path)
  if path:match("/%.git/") then
    return true
  end
  local base = vim.fn.fnamemodify(path, ":t")
  local ephemeral = {
    ["COMMIT_EDITMSG"] = true,
    ["MERGE_MSG"] = true,
    ["TAG_EDITMSG"] = true,
    ["SQUASH_MSG"] = true,
    ["git-rebase-todo"] = true,
    ["addp-hunk-edit.diff"] = true,
  }
  if ephemeral[base] then
    return true
  end
  for _, dir in ipairs({
    vim.env.TMPDIR,
    "/tmp",
    "/private/tmp",
    "/var/folders",
  }) do
    if dir and dir ~= "" then
      local nd = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
      if path:sub(1, #nd + 1) == nd .. "/" then
        return true
      end
    end
  end
  return false
end

--- @return string[]
local function read()
  local f = io.open(store, "r")
  if not f then
    return {}
  end
  local data = f:read("*a")
  f:close()
  local ok, list = pcall(vim.json.decode, data)
  return (ok and type(list) == "table") and list or {}
end

--- @param list string[]
local function write(list)
  local f = io.open(store, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(list))
  f:close()
end

--- Record the current session's command-line file arguments
--- no-op when nvim was launched without file arguments
function M.record()
  local args = vim.fn.argv()
  if type(args) ~= "table" or #args == 0 then
    return
  end
  local list = read()
  for _, arg in ipairs(args) do
    local path = vim.fn.fnamemodify(arg, ":p")
    if vim.fn.filereadable(path) == 1 and not excluded(path) then
      for i = #list, 1, -1 do
        if list[i] == path then
          table.remove(list, i)
        end
      end
      table.insert(list, 1, path)
    end
  end
  while #list > max do
    table.remove(list)
  end
  write(list)
end

--- Dashboard section generator mirroring Snacks.dashboard.sections.recent_files
--- @param opts? { limit?: number }
--- @return fun(): table[]
function M.section(opts)
  opts = opts or {}
  local limit = opts.limit or 5
  return function()
    local ret = {}
    for _, file in ipairs(read()) do
      if vim.fn.filereadable(file) == 1 then
        ret[#ret + 1] = {
          file = file,
          icon = "file",
          action = ":e " .. vim.fn.fnameescape(file),
          autokey = true,
        }
        if #ret >= limit then
          break
        end
      end
    end
    return ret
  end
end

return M
