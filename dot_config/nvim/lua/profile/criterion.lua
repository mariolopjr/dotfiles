--- profile.criterion: parse criterion benchmark timings into a picker list
---
--- criterion writes target/criterion/<id>/new/estimates.json (mean.point_estimate
--- in nanoseconds, mean.standard_error) plus benchmark.json (full_id). A benchmark
--- measures a whole function, so attribution is at function granularity
---
--- NOTE: estimates.json/benchmark.json is an unstable format

local fmt = require("profile.fmt")

local M = {}

--- @param path string
--- @return table?
local function read_json(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local body = fd:read("*a")
  fd:close()
  local ok, data = pcall(vim.json.decode, body)
  if ok then
    return data
  end
  return nil
end

--- Locate the workspace target/criterion directory upward from cwd
--- @return string?
function M.find_dir()
  local target = vim.fs.find("target", {
    upward = true,
    path = vim.fn.getcwd(),
    type = "directory",
    limit = 1,
  })[1]
  if target and vim.fn.isdirectory(target .. "/criterion") == 1 then
    return target .. "/criterion"
  end
  return nil
end

--- Best-effort file:line for a bench id by scanning the bench sources for its id
--- string literal, matching the c.bench_function("id", ...) call
--- @param id string
--- @param bench_root string project root the benches live under
--- @return { file: string, line: integer }?
function M.locate(id, bench_root)
  local files = vim.fn.glob(bench_root .. "/crates/*/benches/*.rs", false, true)
  if #files == 0 then
    files = vim.fn.glob(bench_root .. "/**/benches/*.rs", false, true)
  end
  local needle = '"' .. id .. '"'
  local first
  for _, f in ipairs(files) do
    first = first or f
    local ok, lines = pcall(vim.fn.readfile, f)
    if ok then
      for i, line in ipairs(lines) do
        if line:find(needle, 1, true) then
          return { file = f, line = i }
        end
      end
    end
  end
  if first then
    return { file = first, line = 1 }
  end
  return nil
end

--- @param new_dir string the <id>/new directory holding estimates.json
--- @return string
local function bench_id(new_dir)
  local meta = read_json(new_dir .. "/benchmark.json")
  if meta and type(meta.full_id) == "string" then
    return meta.full_id
  end
  -- fall back to the id directory name, parent of new/
  return vim.fs.basename(vim.fs.dirname(new_dir))
end

--- @param criterion_dir string the target/criterion directory
--- @param bench_root string project root the bench sources live under
--- @return profile.Hotspot[]
function M.hotspots(criterion_dir, bench_root)
  local estimates =
    vim.fn.glob(criterion_dir .. "/**/new/estimates.json", false, true)

  local list = {}
  for _, est_path in ipairs(estimates) do
    local est = read_json(est_path)
    local mean = est and est.mean
    local point = mean and tonumber(mean.point_estimate)
    if mean and point then
      local new_dir = vim.fs.dirname(est_path)
      local id = bench_id(new_dir)
      local se = tonumber(mean.standard_error) or 0
      local loc = M.locate(id, bench_root)
      list[#list + 1] = {
        file = loc and loc.file or "",
        line = loc and loc.line or 1,
        col = 0,
        symbol = id,
        -- ns, larger is slower so it sorts and heats like the other sources
        value = point,
        label = fmt.time(point),
        detail = string.format("±%.1f%%", point > 0 and se / point * 100 or 0),
        metrics = {
          { key = "time", value = point, fmt = fmt.time },
        },
      }
    end
  end

  table.sort(list, function(a, b)
    return a.value > b.value
  end)
  return list
end

return M
