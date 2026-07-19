--- profile.picker: a snacks picker over hotspots from any source
---
--- Items carry file and pos so the default confirm action jumps straight to the
--- hot spot. The format lays out the primary metric, the secondary detail, the
--- location and the symbol in columns. Two in-picker toggles: <a-s> cycles the
--- sort metric (dhat has bytes/allocs/peak), <a-g> groups per enclosing method

local aggregate = require("profile.aggregate")

local M = {}

--- metrics share one shape within a single source, count from the first hotspot
--- @param list profile.Hotspot[]
--- @return integer
local function metric_count(list)
  local h = list[1]
  return h and h.metrics and #h.metrics or 1
end

--- the number at the active metric, for sorting, without formatting
--- @param h profile.Hotspot
--- @param active integer
--- @return number
local function value_at(h, active)
  local m = h.metrics and h.metrics[active]
  return m and m.value or h.value or 0
end

--- the formatted primary text at the active metric
--- @param h profile.Hotspot
--- @param active integer
--- @return string
local function text_at(h, active)
  local m = h.metrics and h.metrics[active]
  if m then
    return m.fmt(m.value)
  end
  return h.label or ""
end

--- secondary column: the other metrics when there is more than one, else detail
--- @param h profile.Hotspot
--- @param active integer
--- @return string
local function secondary(h, active)
  if h.metrics and #h.metrics > 1 then
    local parts = {}
    for i, m in ipairs(h.metrics) do
      if i ~= active then
        parts[#parts + 1] = m.fmt(m.value)
      end
    end
    return table.concat(parts, "  ")
  end
  return h.detail or ""
end

--- @param list profile.Hotspot[]
--- @param title string
function M.open(list, title)
  if not (Snacks and Snacks.picker) then
    vim.notify("profile: snacks picker is not available", vim.log.levels.ERROR)
    return
  end
  if #list == 0 then
    vim.notify(
      "profile: no hotspots resolved to files in this project",
      vim.log.levels.WARN
    )
    return
  end

  local mcount = metric_count(list)
  local active = 1
  local by_method = false
  local picker

  -- items for the current view, idx reassigned so the empty query keeps order
  local function build()
    local view = by_method and aggregate.by_method(list) or list
    table.sort(view, function(a, b)
      return value_at(a, active) > value_at(b, active)
    end)
    local items = {}
    for i, h in ipairs(view) do
      items[i] = {
        idx = i,
        file = h.file,
        pos = { h.line, math.max((h.col or 1) - 1, 0) },
        text = table.concat({ h.symbol, h.file, tostring(h.line) }, " "),
        hotspot = h,
      }
    end
    return items
  end

  local function rebuild()
    if picker then
      picker.opts.items = build()
      picker:find({ refresh = true })
    end
  end

  picker = Snacks.picker.pick({
    title = title or "Hotspots",
    items = build(),
    format = function(item)
      local h = item.hotspot
      local rel = vim.fn.fnamemodify(h.file, ":.")
      return {
        { string.format("%10s", text_at(h, active)), "ProfileHeatHigh" },
        { "  ", "SnacksPickerDelim" },
        { string.format("%-16s", secondary(h, active)), "SnacksPickerComment" },
        { "  ", "SnacksPickerDelim" },
        { rel .. ":" .. h.line, "SnacksPickerFile" },
        { "  ", "SnacksPickerDelim" },
        { h.symbol, "SnacksPickerComment" },
      }
    end,
    preview = "file",
    actions = {
      profile_sort = function()
        if mcount < 2 then
          vim.notify("profile: single metric, nothing to cycle")
          return
        end
        active = active % mcount + 1
        rebuild()
        vim.notify("profile: sort by " .. list[1].metrics[active].key)
      end,
      profile_methods = function()
        by_method = not by_method
        rebuild()
        vim.notify("profile: " .. (by_method and "per method" or "per line"))
      end,
    },
    win = {
      input = {
        keys = {
          ["<a-s>"] = { "profile_sort", mode = { "i", "n" } },
          ["<a-g>"] = { "profile_methods", mode = { "i", "n" } },
        },
      },
    },
  })
end

return M
