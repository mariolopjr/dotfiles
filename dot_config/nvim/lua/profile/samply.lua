--- profile.samply: parse a samply cpu profile into per-function hotspots
---
--- samply saves a Firefox Profiler json of raw addresses plus a .syms.json
--- sidecar (from --unstable-presymbolicate) mapping each lib's address ranges to
--- symbols and inline frames with file:line. A sample is attributed to the
--- deepest project frame: walk its stack leaf to root, symbolicate each address
--- through the sidecar, and within a symbol walk its inline frames innermost
--- first, taking the first file that lives under the project.

local fmt = require("profile.fmt")
local resolve_mod = require("profile.resolve")

local NIL = vim.NIL

local M = {}

--- @param v any
--- @return any
local function nn(v)
  if v == nil or v == NIL then
    return nil
  end
  return v
end

--- @param data table decoded profile json
--- @return boolean
function M.matches(data)
  return type(data) == "table"
    and type(data.threads) == "table"
    and type(data.libs) == "table"
    and type(data.meta) == "table"
end

--- Build address to symbol lookup from the sidecar, one sorted table per lib
--- @param syms table decoded .syms.json
--- @return fun(lib: string?, addr: integer): table[]?
local function make_symbolicator(syms)
  local st = syms.string_table or {}
  local by_lib = {}
  for _, entry in ipairs(syms.data or {}) do
    local arr = {}
    for _, s in ipairs(entry.symbol_table or {}) do
      local inlines = {}
      local frames = nn(s.frames)
      if frames then
        -- innermost inline frame first, matching the sidecar order
        for _, fr in ipairs(frames) do
          local fidx = nn(fr.file)
          inlines[#inlines + 1] = {
            name = st[nn(fr["function"]) and fr["function"] + 1 or 0] or "?",
            file = fidx and st[fidx + 1] or nil,
            line = nn(fr.line),
          }
        end
      else
        inlines = { { name = st[nn(s.symbol) and s.symbol + 1 or 0] or "?" } }
      end
      arr[#arr + 1] = { rva = s.rva, size = nn(s.size), inlines = inlines }
    end
    table.sort(arr, function(a, b)
      return a.rva < b.rva
    end)
    by_lib[entry.debug_name] = arr
  end

  return function(lib, addr)
    local arr = lib and by_lib[lib]
    if not arr then
      return nil
    end
    -- greatest rva <= addr, then confirm addr is inside its size
    local lo, hi, best = 1, #arr, nil
    while lo <= hi do
      local mid = math.floor((lo + hi) / 2)
      if arr[mid].rva <= addr then
        best = arr[mid]
        lo = mid + 1
      else
        hi = mid - 1
      end
    end
    if best and (not best.size or addr < best.rva + best.size) then
      return best.inlines
    end
    return nil
  end
end

--- @param profile table decoded profile json
--- @param syms table decoded sidecar json
--- @param resolve fun(path: string?): string?
--- @param project_root string only frames under here are attributed
--- @return profile.Hotspot[]
function M.hotspots(profile, syms, resolve, project_root)
  local symbolicate = make_symbolicator(syms)
  local libs = profile.libs

  local agg = {}
  local total = 0

  for _, t in ipairs(profile.threads) do
    local frame, prefix = t.stackTable.frame, t.stackTable.prefix
    local f_func, f_addr = t.frameTable.func, t.frameTable.address
    local fn_res = t.funcTable.resource
    local res_lib = t.resourceTable.lib
    local stacks = t.samples.stack

    for s = 1, t.samples.length do
      total = total + 1
      local stack0 = nn(stacks[s])
      while stack0 do
        local frame0 = frame[stack0 + 1]
        local func0 = nn(f_func[frame0 + 1])
        local res0 = func0 and nn(fn_res[func0 + 1])
        local lib0 = res0 and res0 >= 0 and nn(res_lib[res0 + 1])
        local lib = lib0 and libs[lib0 + 1] and libs[lib0 + 1].debugName or nil
        local inlines = symbolicate(lib, f_addr[frame0 + 1])
        local attributed = false
        if inlines then
          for _, il in ipairs(inlines) do
            local file = il.file and resolve(il.file)
            if file and resolve_mod.is_under(project_root, file) then
              local line = il.line or 1
              local key = file .. "\0" .. line
              local a = agg[key]
              if not a then
                a = { file = file, line = line, symbol = il.name, self = 0 }
                agg[key] = a
              end
              a.self = a.self + 1
              attributed = true
              break
            end
          end
        end
        if attributed then
          break
        end
        stack0 = nn(prefix[stack0 + 1])
      end
    end
  end

  total = math.max(total, 1)
  local function pct_fmt(v)
    return fmt.pct(v / total)
  end

  local list = {}
  for _, a in pairs(agg) do
    list[#list + 1] = {
      file = a.file,
      line = a.line,
      col = 0,
      symbol = a.symbol,
      value = a.self,
      label = pct_fmt(a.self),
      detail = fmt.count(a.self) .. " samples",
      metrics = {
        { key = "samples", value = a.self, fmt = pct_fmt },
      },
    }
  end
  table.sort(list, function(x, y)
    return x.value > y.value
  end)
  return list
end

return M
