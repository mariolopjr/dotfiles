-- Renumber markdown footnotes so their numbers follow the order the refs first
-- appear in the body, then reorder the definition lines to match

local M = {}

-- Match a footnote definition marker at the start of a line, `[^id]: ...`
---@param line string
---@return string? id
M.parse_definition = function(line)
  return line:match("^%s*%[%^([^%]%[%s]+)%]:")
end

-- Whether a line opens or closes a fenced code block
---@param line string
---@return boolean
local function is_fence(line)
  return line:match("^%s*```") ~= nil or line:match("^%s*~~~") ~= nil
end

-- Renumber footnotes in a buffer into reading order, reordering the definition
-- lines to match. Return without changes when refs and definitions are
-- inconsistent, a ref with no definition or a definition never referenced
---@param bufnr integer|?
M.renumber = function(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  ---@type { id: string, lnum: integer }[]
  local defs = {}
  local def_lnums = {} -- id: list of definition line numbers, to catch duplicates
  local order = {} -- ids in order of first body reference
  local seen_ref = {}
  local ref_ids = {} -- id: true for every id referenced in the body

  local in_fence = false
  for lnum, line in ipairs(lines) do
    if is_fence(line) then
      in_fence = not in_fence
    elseif not in_fence then
      local def_id = M.parse_definition(line)
      if def_id then
        defs[#defs + 1] = { id = def_id, lnum = lnum }
        def_lnums[def_id] = def_lnums[def_id] or {}
        table.insert(def_lnums[def_id], lnum)
      else
        for id in line:gmatch("%[%^([^%]%[%s]+)%]") do
          ref_ids[id] = true
          if not seen_ref[id] then
            seen_ref[id] = true
            order[#order + 1] = id
          end
        end
      end
    end
  end

  if #defs == 0 and #order == 0 then
    return vim.notify("No footnotes found", vim.log.levels.INFO)
  end

  -- consistency checks
  local def_ids = {}
  for _, d in ipairs(defs) do
    def_ids[d.id] = true
  end

  local problems = {}
  for _, id in ipairs(order) do
    if not def_ids[id] then
      problems[#problems + 1] = ("ref [^%s] has no definition"):format(id)
    end
  end
  for _, d in ipairs(defs) do
    if not ref_ids[d.id] then
      problems[#problems + 1] = ("definition [^%s] (line %d) is never referenced"):format(
        d.id,
        d.lnum
      )
    end
  end
  for id, ls in pairs(def_lnums) do
    if #ls > 1 then
      problems[#problems + 1] = ("[^%s] defined %d times (lines %s)"):format(
        id,
        #ls,
        table.concat(ls, ", ")
      )
    end
  end

  if #problems > 0 then
    return vim.notify(
      "Footnotes not renumbered:\n  " .. table.concat(problems, "\n  "),
      vim.log.levels.WARN
    )
  end

  -- old id to new number from the referenced order
  local map = {}
  for i, id in ipairs(order) do
    map[id] = i
  end

  local function rename(line)
    return (
      line:gsub("%[%^([^%]%[%s]+)%]", function(id)
        return "[^" .. (map[id] or id) .. "]"
      end)
    )
  end

  -- rewrite refs and definition markers across the buffer, skipping fences
  in_fence = false
  local out = {}
  for _, line in ipairs(lines) do
    if is_fence(line) then
      in_fence = not in_fence
      out[#out + 1] = line
    elseif in_fence then
      out[#out + 1] = line
    else
      out[#out + 1] = rename(line)
    end
  end

  -- reorder the renamed definition lines into their existing slots, ascending
  local slots = {}
  local renamed_defs = {}
  for _, d in ipairs(defs) do
    slots[#slots + 1] = d.lnum
    renamed_defs[#renamed_defs + 1] = out[d.lnum]
  end
  table.sort(slots)
  table.sort(renamed_defs, function(a, b)
    return (tonumber(M.parse_definition(a)) or 0)
      < (tonumber(M.parse_definition(b)) or 0)
  end)
  for i, lnum in ipairs(slots) do
    out[lnum] = renamed_defs[i]
  end

  -- skip the write when nothing actually moved
  local changed = false
  for i = 1, #lines do
    if lines[i] ~= out[i] then
      changed = true
      break
    end
  end
  if not changed then
    return vim.notify("Footnotes already in order", vim.log.levels.INFO)
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out)
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)

  vim.notify(("Renumbered %d footnotes"):format(#order), vim.log.levels.INFO)
end

return M
