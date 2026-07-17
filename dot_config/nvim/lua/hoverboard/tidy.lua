--- Markdown tidy passes over raw hover lines, everything that must happen
--- before the float opens and sizes itself
---
--- A hover is structured as an optional preamble (rustaceanvim prepends its
--- numbered actions and a separator), a signature panel (rust-analyzer sends
--- defining crate and item signature as two fenced blocks), a separator and
--- the doc body. Tidying merges the signature blocks into one, replaces
--- inline links with their label while recording what each pointed at, a
--- concealed target still occupies wrap width and breaks lines early, and
--- re-aligns pipe table columns to their rendered widths

local M = {}

--- Lines allowed before the signature blocks, rustaceanvim's numbered hover
--- actions and their separator
--- @param line string
--- @return boolean
local function is_preamble(line)
  local t = vim.trim(line)
  return t == ""
    or t:match("^%d+%. ") ~= nil
    or t:match("^[-_*][-_*][-_*]+$") ~= nil
end

--- Merge the run of same-language fenced blocks the signature panel is made
--- of, keeping everything else untouched. Blocks in the run may be separated
--- by blank lines only
--- @param lines string[]
--- @return string[]
local function merge_leading_blocks(lines)
  local first
  for i, line in ipairs(lines) do
    if vim.trim(line):match("^```%S") then
      first = i
      break
    elseif not is_preamble(line) then
      return lines
    end
  end
  local lang = first and vim.trim(lines[first]):match("^```(%S+)%s*$")
  if not lang then
    return lines
  end

  local fence = "```" .. lang
  local body = {}
  local i = first
  while lines[i] and vim.trim(lines[i]) == fence do
    i = i + 1
    while lines[i] and vim.trim(lines[i]) ~= "```" do
      body[#body + 1] = lines[i]
      i = i + 1
    end
    if not lines[i] then
      -- unterminated block, leave the input alone
      return lines
    end
    i = i + 1

    -- the run continues only across blank lines into another block
    local j = i
    while lines[j] and vim.trim(lines[j]) == "" do
      j = j + 1
    end
    if lines[j] and vim.trim(lines[j]) == fence then
      i = j
    else
      break
    end
  end

  local out = {}
  vim.list_extend(out, lines, 1, first - 1)
  out[#out + 1] = fence
  vim.list_extend(out, body)
  out[#out + 1] = "```"
  vim.list_extend(out, lines, i, #lines)
  return out
end

--- Replace one line's inline links with their labels, recording the byte
--- span each label lands on and the target it pointed at. Targets arrive
--- as urls or as rustdoc item paths wrapped in backticks. Inline code owns
--- its bytes, brackets inside a code span are not links
--- @param line string
--- @return string flat
--- @return { scol: integer, ecol: integer, target: string }[]
local function delink(line)
  local out = {}
  local spans = {}
  local len = 0
  local i = 1
  while true do
    local s = line:find("[", i, true)
    if not s then
      break
    end
    local tick = line:find("`", i, true)
    if tick and tick < s then
      -- copy the whole code span through, an unterminated span runs to
      -- the end of the line
      local close = line:find("`", tick + 1, true)
      local chunk = line:sub(i, close or #line)
      out[#out + 1] = chunk
      len = len + #chunk
      i = (close or #line) + 1
    else
      local label = line:match("^%b[]", s)
      local target = label and line:match("^%b()", s + #label)
      if not target then
        -- a literal bracket, copy it through and keep scanning
        local chunk = line:sub(i, s)
        out[#out + 1] = chunk
        len = len + #chunk
        i = s + 1
      else
        local chunk = line:sub(i, s - 1)
        out[#out + 1] = chunk
        len = len + #chunk
        local text = label:sub(2, -2)
        spans[#spans + 1] = {
          scol = len,
          ecol = len + #text,
          target = (vim.trim(target:sub(2, -2)):gsub("^`(.*)`$", "%1")),
        }
        out[#out + 1] = text
        len = len + #text
        i = s + #label + #target
      end
    end
  end
  out[#out + 1] = line:sub(i)
  return table.concat(out), spans
end

--- Drop backslash escapes from prose, gdext escapes Godot's [member X]
--- references so rustdoc reads them literally and the backslashes would
--- survive into the float. Inline code spans keep their bytes, and escaped
--- pipes stay on table-shaped lines because the table passes own them and
--- a cell's literal pipe must not become a cell boundary
--- @param line string
--- @param keep_pipes boolean?
--- @return string
local function unescape_prose(line, keep_pipes)
  local parts = vim.split(line, "`", { plain = true })
  for i = 1, #parts, 2 do
    parts[i] = parts[i]:gsub("\\(%p)", function(c)
      if keep_pipes and c == "|" then
        return "\\|"
      end
      return c
    end)
  end
  return table.concat(parts, "`")
end

--- @param lines string[]
--- @return string[]
local function unescape(lines)
  local in_code = false
  for i, line in ipairs(lines) do
    if vim.trim(line):match("^```") then
      in_code = not in_code
    elseif not in_code and line:find("\\", 1, true) then
      lines[i] = unescape_prose(line, line:match("^%s*\\?|.*|%s*$") ~= nil)
    end
  end
  return lines
end

--- Strip inline links down to their labels outside code blocks and collect
--- where each target can be followed from. Table rows are re-laid out by
--- align_tables so their spans would not survive, those links lose their
--- targets and only keep the label
--- @param lines string[]
--- @return string[]
--- @return { row: integer, scol: integer, ecol: integer, target: string }[]
local function extract_links(lines)
  local links = {}
  local in_code = false
  for i, line in ipairs(lines) do
    if vim.trim(line):match("^```") then
      in_code = not in_code
    elseif not in_code and line:find("](", 1, true) then
      local flat, spans = delink(line)
      lines[i] = flat
      if not flat:match("^%s*\\?|.*|%s*$") then
        for _, s in ipairs(spans) do
          links[#links + 1] =
            { row = i, scol = s.scol, ecol = s.ecol, target = s.target }
        end
      end
    end
  end
  return lines, links
end

--- Flatten a table cell: inline code and bold markers are removed outright
--- because conceal only hides them from display while they still count
--- toward wrap width and float sizing. Spans over the remaining text carry
--- the styling for decorate to reapply
--- @param cell string
--- @return string plain
--- @return { scol: integer, ecol: integer, code: boolean?, bold: boolean? }[]
local function flatten_cell(cell)
  -- the escape guards table structure, not the code span it may sit in, so
  -- it drops before inline markup is read
  cell = cell:gsub("\\|", "|")
  local out = {}
  local spans = {}
  local len = 0
  local bold_from
  local i = 1
  while i <= #cell do
    if cell:sub(i, i + 1) == "**" then
      if bold_from then
        spans[#spans + 1] = { scol = bold_from, ecol = len, bold = true }
        bold_from = nil
      elseif cell:find("**", i + 2, true) then
        bold_from = len
      else
        -- a marker that never closes is literal text
        out[#out + 1] = "**"
        len = len + 2
      end
      i = i + 2
    elseif cell:sub(i, i) == "`" then
      local close = cell:find("`", i + 1, true)
      if close then
        local text = cell:sub(i + 1, close - 1)
        spans[#spans + 1] = { scol = len, ecol = len + #text, code = true }
        out[#out + 1] = text
        len = len + #text
        i = close + 1
      else
        out[#out + 1] = "`"
        len = len + 1
        i = i + 1
      end
    else
      out[#out + 1] = cell:sub(i, i)
      len = len + 1
      i = i + 1
    end
  end
  return table.concat(out), spans
end

--- @param row string
--- @return string[]
local function split_cells(row)
  local cells = {}
  local from = (row:find("|", 1, true) or 0) + 1
  local i = from
  while i <= #row do
    local c = row:sub(i, i)
    if c == "\\" and row:sub(i + 1, i + 1) == "|" then
      -- an escaped pipe belongs to its cell
      i = i + 2
    elseif c == "|" then
      cells[#cells + 1] = vim.trim(row:sub(from, i - 1))
      from = i + 1
      i = i + 1
    else
      i = i + 1
    end
  end
  -- anything after the closing pipe
  local tail = vim.trim(row:sub(from))
  if tail ~= "" then
    cells[#cells + 1] = tail
  end
  return cells
end

--- rust-analyzer escapes the leading pipe of doc comment table rows, which
--- breaks markdown parsing and table detection alike, unescape lines that
--- otherwise read as a table row
--- @param lines string[]
--- @return string[]
local function unescape_tables(lines)
  local in_code = false
  for i, line in ipairs(lines) do
    if vim.trim(line):match("^```") then
      in_code = not in_code
    elseif not in_code and line:match("^%s*\\|.*|%s*$") then
      lines[i] = line:gsub("^(%s*)\\|", "%1|", 1)
    end
  end
  return lines
end

--- Re-align pipe tables to flattened cell text, keeping the markdown valid
--- for treesitter. Column alignment colons are normalized away. The second
--- return carries the styling spans and table count for decorate
--- @param lines string[]
--- @return string[]
--- @return { tables: integer, spans: table[], pipes: table[] }
local function align_tables(lines)
  local out = {}
  local marks = { tables = 0, spans = {}, pipes = {} }
  local in_code = false
  local i = 1
  while i <= #lines do
    local line = lines[i]
    if vim.trim(line):match("^```") then
      in_code = not in_code
    end

    local delim = lines[i + 1] and lines[i + 1]:match("^%s*|[%s:%-|]+|%s*$")
    if not in_code and line:match("^%s*|.*|%s*$") and delim then
      marks.tables = marks.tables + 1
      local rows = {}
      while lines[i] and lines[i]:match("^%s*|.*|%s*$") do
        local cells = {}
        for _, cell in ipairs(split_cells(lines[i])) do
          local plain, spans = flatten_cell(cell)
          cells[#cells + 1] = { text = plain, spans = spans }
        end
        rows[#rows + 1] = cells
        i = i + 1
      end

      -- widths over all data rows, the delimiter row is regenerated
      local widths = {}
      for r, cells in ipairs(rows) do
        if r ~= 2 then
          for c, cell in ipairs(cells) do
            widths[c] =
              math.max(widths[c] or 3, vim.fn.strdisplaywidth(cell.text))
          end
        end
      end

      for r, cells in ipairs(rows) do
        local parts = {}
        local offset = 2
        -- unescaped literal pipes in cell text read like separators, only
        -- these byte columns hold structure
        local cols = { 0 }
        for c, width in ipairs(widths) do
          if r == 2 then
            parts[c] = ("-"):rep(width)
          else
            local cell = cells[c] or { text = "", spans = {} }
            for _, s in ipairs(cell.spans) do
              marks.spans[#marks.spans + 1] = {
                t = marks.tables,
                row = r - 1,
                scol = offset + s.scol,
                ecol = offset + s.ecol,
                code = s.code,
                bold = s.bold,
              }
            end
            parts[c] = cell.text
              .. (" "):rep(width - vim.fn.strdisplaywidth(cell.text))
          end
          offset = offset + #parts[c] + 3
          cols[#cols + 1] = offset - 2
        end
        marks.pipes[#marks.pipes + 1] =
          { t = marks.tables, row = r - 1, cols = cols }
        out[#out + 1] = "| " .. table.concat(parts, " | ") .. " |"
      end
    else
      out[#out + 1] = line
      i = i + 1
    end
  end
  return out, marks
end

--- Language used to color flattened cell values, the signature fence names
--- it, hovers without a fenced block fall back to the source buffer
--- @param lines string[]
--- @return string?
function M.fragment_lang(lines)
  for _, line in ipairs(lines) do
    local fence = vim.trim(line):match("^```(%S+)")
    if fence then
      return vim.treesitter.language.get_lang(fence)
    end
  end
  return vim.treesitter.language.get_lang(vim.bo.filetype)
end

--- All tidy passes over raw hover lines, which are mutated along the way
--- @param contents string[]
--- @return string[] lines
--- @return { tables: integer, spans: table[], pipes: table[] } table_marks
--- @return { row: integer, scol: integer, ecol: integer, target: string }[] links
function M.tidy(contents)
  -- unescape before link spans are recorded, dropped backslashes shift the
  -- columns of everything after them
  local lines, links = extract_links(unescape(merge_leading_blocks(contents)))
  local aligned, table_marks = align_tables(unescape_tables(lines))
  return aligned, table_marks, links
end

return M
