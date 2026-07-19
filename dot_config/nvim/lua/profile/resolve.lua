--- profile.resolve: turn a profiler frame's path into a real file on disk
---
--- Frame paths come in two shapes: relative (dhat records game_core/src/x.rs)
--- and absolute (samply's symbol sidecar records the full path). Relative paths
--- join onto the json dir, its ancestors and the cwd, then fall back to finding
--- a project file whose path ends with the frame path, since cargo often drops
--- the crates/ prefix. Absolute paths resolve directly. Callers that only want
--- project files (not std or dependency sources, which exist on disk too) filter
--- the result with is_under

local M = {}

--- @param root string
--- @param path string
--- @return boolean
function M.is_under(root, path)
  if not root or not path then
    return false
  end
  root = root:gsub("/$", "")
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

--- @param json_dir string directory the artifact lives in
--- @param extra_root string?
--- @return fun(path: string?): string?
function M.make(json_dir, extra_root)
  local roots, seen = {}, {}
  local function add(d)
    if d and d ~= "" and not seen[d] then
      seen[d] = true
      roots[#roots + 1] = d
    end
  end
  add(extra_root)
  add(vim.fn.getcwd())
  local d = json_dir
  for _ = 1, 8 do
    add(d)
    local parent = vim.fs.dirname(d)
    if not parent or parent == d then
      break
    end
    d = parent
  end

  -- bound the suffix search to the project, git root of the json if there is one
  local search_root = vim.fs.root(json_dir, ".git") or json_dir

  local cache, by_base = {}, {}
  return function(path)
    if not path then
      return nil
    end
    local hit = cache[path]
    if hit ~= nil then
      return hit or nil
    end
    if path:sub(1, 1) == "/" and vim.uv.fs_stat(path) then
      cache[path] = path
      return path
    end
    for _, root in ipairs(roots) do
      local cand = root .. "/" .. path
      if vim.uv.fs_stat(cand) then
        cand = vim.fs.normalize(cand)
        cache[path] = cand
        return cand
      end
    end

    -- suffix match by basename, scanned once per basename and cached
    local base = vim.fs.basename(path)
    local found = by_base[base]
    if not found then
      found =
        vim.fs.find(base, { path = search_root, type = "file", limit = 100 })
      by_base[base] = found
    end
    local want = "/" .. path
    for _, c in ipairs(found) do
      local n = vim.fs.normalize(c)
      if n == path or n:sub(-#want) == want then
        cache[path] = n
        return n
      end
    end

    cache[path] = false
    return nil
  end
end

return M
