--- profile.dhat: parse a decoded dhat-heap.json into per-line hotspots
---
--- dhat writes a frame table (ftbl) of "0xaddr: symbol (path:line:col)" strings
--- and a list of program points (pps). Each pp carries totals (tb bytes, tbk
--- blocks) and fs, the call stack as 0-based indices into ftbl ordered leaf to
--- root. An allocation is attributed to the deepest frame whose path resolves to
--- a real file, which skips the std and allocator frames

local fmt = require("profile.fmt")

local M = {}

--- @param data table decoded dhat json
--- @return boolean
function M.matches(data)
  return type(data) == "table"
    and data.dhatFileVersion ~= nil
    and type(data.ftbl) == "table"
    and type(data.pps) == "table"
end

--- @param s string one ftbl entry
--- @return string symbol, string? path, integer? line, integer? col
local function parse_frame(s)
  local body = s:gsub("^0x%x+:%s*", "")
  local path, line, col = body:match("%((.-):(%d+):(%d+)%)%s*$")
  if not path then
    path, line = body:match("%((.-):(%d+)%)%s*$")
  end
  local symbol = body:gsub("%s*%b()%s*$", "")
  return symbol,
    path,
    line and tonumber(line) or nil,
    col and tonumber(col) or nil
end

--- @param data table decoded dhat json
--- @param resolve fun(path: string?): string?
--- @return profile.Hotspot[]
function M.hotspots(data, resolve)
  local frames = {}
  for i, s in ipairs(data.ftbl) do
    local symbol, path, line, col = parse_frame(s)
    frames[i] = { symbol = symbol, path = path, line = line, col = col }
  end

  local agg = {}
  for _, pp in ipairs(data.pps) do
    for _, idx0 in ipairs(pp.fs or {}) do
      -- fs holds 0-based indices, lua arrays are 1-based
      local fr = frames[idx0 + 1]
      if fr and fr.path and fr.line then
        local file = resolve(fr.path)
        if file then
          local key = file .. "\0" .. fr.line
          local a = agg[key]
          if not a then
            a = {
              file = file,
              line = fr.line,
              col = fr.col or 0,
              symbol = fr.symbol,
              bytes = 0,
              blocks = 0,
              peak = 0,
            }
            agg[key] = a
          end
          a.bytes = a.bytes + (pp.tb or 0)
          a.blocks = a.blocks + (pp.tbk or 0)
          -- mb is a program point's own max-live bytes, summing across the
          -- points on a line is total peak pressure not one simultaneous peak
          a.peak = a.peak + (pp.mb or 0)
          break
        end
      end
    end
  end

  local function allocs_fmt(v)
    return fmt.count(v) .. " allocs"
  end

  local list = {}
  for _, a in pairs(agg) do
    list[#list + 1] = {
      file = a.file,
      line = a.line,
      col = a.col,
      symbol = a.symbol,
      value = a.bytes,
      label = fmt.bytes(a.bytes),
      detail = allocs_fmt(a.blocks),
      metrics = {
        { key = "bytes", value = a.bytes, fmt = fmt.bytes },
        { key = "allocs", value = a.blocks, fmt = allocs_fmt },
        { key = "peak", value = a.peak, fmt = fmt.bytes },
      },
    }
  end
  table.sort(list, function(x, y)
    return x.value > y.value
  end)
  return list
end

return M
