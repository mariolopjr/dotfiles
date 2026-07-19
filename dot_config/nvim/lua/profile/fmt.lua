--- profile.fmt: number formatting shared by the parsers

--- @class profile.Metric
--- @field key string one of "bytes"|"allocs"|"peak"|"samples"|"time"
--- @field value number
--- @field fmt fun(v: number): string formats value, recomputed after aggregation

--- @class profile.Hotspot
--- @field file string absolute path, resolved
--- @field line integer
--- @field col integer
--- @field symbol string
--- @field value number primary metric, drives sort order and heat
--- @field label string formatted primary metric, "36.6 MB" or "42.1%"
--- @field detail string formatted secondary, "400.0k allocs" or "1.2k samples"
--- @field metrics profile.Metric[] sortable metrics, [1] is the primary that drives value/label

local M = {}

--- @param n integer
--- @return string
function M.bytes(n)
  local units = { "B", "KB", "MB", "GB", "TB" }
  local v, u = n, 1
  while v >= 1024 and u < #units do
    v = v / 1024
    u = u + 1
  end
  return u == 1 and string.format("%d B", n)
    or string.format("%.1f %s", v, units[u])
end

--- @param n integer
--- @return string
function M.count(n)
  if n >= 1e6 then
    return string.format("%.1fM", n / 1e6)
  elseif n >= 1e3 then
    return string.format("%.1fk", n / 1e3)
  end
  return tostring(n)
end

--- @param ratio number 0..1
--- @return string
function M.pct(ratio)
  return string.format("%.1f%%", ratio * 100)
end

--- @param ns number nanoseconds
--- @return string
function M.time(ns)
  local units = { { 1, "ns" }, { 1e3, "µs" }, { 1e6, "ms" }, { 1e9, "s" } }
  local u = units[1]
  for _, cand in ipairs(units) do
    if ns >= cand[1] then
      u = cand
    end
  end
  return string.format("%.1f %s", ns / u[1], u[2])
end

return M
