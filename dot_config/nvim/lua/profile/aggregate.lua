--- profile.aggregate: roll per-line hotspots up to their enclosing function

local M = {}

--- Fold a trailing closure segment into its parent so a method and its closures
--- aggregate together. Leaves generic args and closure type-parameters alone
--- @param symbol string
--- @return string
local function normalize(symbol)
  local s = symbol or ""
  s = s:gsub("::{{closure}}$", "")
  s = s:gsub("::{closure#%d+}$", "")
  return s
end

--- @param list profile.Hotspot[]
--- @return profile.Hotspot[]
function M.by_method(list)
  local groups, order = {}, {}
  for _, h in ipairs(list) do
    local key = (h.file or "") .. "\0" .. normalize(h.symbol or "")
    local g = groups[key]
    if not g then
      g = {
        file = h.file,
        line = h.line,
        col = h.col,
        symbol = normalize(h.symbol or ""),
        value = 0,
        detail = h.detail,
        metrics = {},
        _top = -math.huge,
      }
      -- clone the metric shape (key + fmt), values summed below
      for i, m in ipairs(h.metrics or {}) do
        g.metrics[i] = { key = m.key, value = 0, fmt = m.fmt }
      end
      groups[key] = g
      order[#order + 1] = key
    end
    g.value = g.value + (h.value or 0)
    for i, m in ipairs(h.metrics or {}) do
      if g.metrics[i] then
        g.metrics[i].value = g.metrics[i].value + (m.value or 0)
      end
    end
    -- anchor on the constituent with the largest primary value
    if (h.value or 0) > g._top then
      g._top = h.value or 0
      g.line = h.line
      g.col = h.col
    end
  end

  local out = {}
  for _, key in ipairs(order) do
    local g = groups[key]
    g._top = nil
    local m1 = g.metrics[1]
    g.label = m1 and m1.fmt(m1.value) or tostring(g.value)
    out[#out + 1] = g
  end
  table.sort(out, function(a, b)
    return a.value > b.value
  end)
  return out
end

return M
