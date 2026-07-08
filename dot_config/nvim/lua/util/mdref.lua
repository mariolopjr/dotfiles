-- Insert CommonMark reference-style links and auto-create their definition
-- Modeled on obsidian.nvim's obsidian/footnotes.lua, but for [label] / [label]: url
-- reference links placed under a `# References` heading

local M = {}

---@class util.mdref.Definition
---@field label string the reference label, the text inside the brackets
---@field lnum integer 1-indexed line number of the definition
---@field text string definition content, the text after the colon

-- Parse a link-reference definition like `[label]: https://example.com`
-- Footnote definitions (`[^id]: ...`) are rejected
---@param line string
---@return string? label
---@return string? text
M.parse_definition = function(line)
  local label, text = line:match("^%[([^%]]+)%]:%s*(.*)$")
  if label and label:sub(1, 1) ~= "^" then
    return label, text
  end
end

-- Collect all reference-link definitions in a buffer
---@param bufnr integer|?
---@return util.mdref.Definition[]
M.definitions = function(bufnr)
  bufnr = bufnr or 0
  ---@type util.mdref.Definition[]
  local defs = {}
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local label, text = M.parse_definition(line)
    if label then
      defs[#defs + 1] = { label = label, lnum = lnum, text = text or "" }
    end
  end
  return defs
end

-- Find the definition for a given label
---@param bufnr integer|?
---@param label string
---@return util.mdref.Definition|?
M.find_definition = function(bufnr, label)
  for _, def in ipairs(M.definitions(bufnr)) do
    if def.label == label then
      return def
    end
  end
end

-- Locate the `# References` or `# References/Notes` heading
---@param bufnr integer|?
---@return integer? lnum 1-indexed line number of the heading
---@return integer? level number of leading hashes
M.references_section = function(bufnr)
  bufnr = bufnr or 0
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local hashes = line:match("^(#+)%s+References%s*$")
      or line:match("^(#+)%s+References/Notes%s*$")
    if hashes then
      return lnum, #hashes
    end
  end
end

-- Append a definition under the `# References` section, creating the heading
-- at the end of the buffer when it is missing
---@param bufnr integer
---@param label string
---@param url string
M.insert_definition = function(bufnr, label, url)
  local def_line = ("[%s]: %s"):format(label, url)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line_count = #lines
  local heading_lnum, heading_level = M.references_section(bufnr)

  if not heading_lnum then
    -- no references section, create it at the end of the buffer
    local new_lines = {}
    if line_count > 0 and vim.trim(lines[line_count]) ~= "" then
      new_lines[#new_lines + 1] = ""
    end
    new_lines[#new_lines + 1] = "# References"
    new_lines[#new_lines + 1] = ""
    new_lines[#new_lines + 1] = def_line
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, new_lines)
    return
  end

  -- the section ends at the first heading of level <= its own, else at the
  -- end of the buffer
  local section_end = line_count
  for lnum = heading_lnum + 1, line_count do
    local hashes = lines[lnum]:match("^(#+)%s")
    if hashes and #hashes <= heading_level then
      section_end = lnum - 1
      break
    end
  end

  -- last non-blank line inside the section, falling back to the heading
  local last = section_end
  while last > heading_lnum and vim.trim(lines[last]) == "" do
    last = last - 1
  end

  -- stack under an existing definition, otherwise separate from the heading
  -- or its blockquote prompt with a blank line
  local new_lines = {}
  if not M.parse_definition(lines[last]) then
    new_lines[#new_lines + 1] = ""
  end
  new_lines[#new_lines + 1] = def_line
  vim.api.nvim_buf_set_lines(bufnr, last, last, false, new_lines)
end

-- Return focus to `win` and place the cursor just after the inserted marker,
-- re-entering insert mode when the binding was triggered there
---@param win integer
---@param bufnr integer
---@param row integer 1-indexed
---@param col integer 0-indexed column where the marker was inserted
---@param marker_len integer
---@param mode string
local function place_after_marker(win, bufnr, row, col, marker_len, mode)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.api.nvim_set_current_win(win)
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local target = col + marker_len

  if mode == "i" then
    if target >= #line then
      -- marker sits at the end of the line, append there
      pcall(vim.api.nvim_win_set_cursor, win, { row, math.max(#line - 1, 0) })
      vim.cmd("startinsert!")
    else
      -- insert before the character following the marker
      pcall(vim.api.nvim_win_set_cursor, win, { row, target })
      vim.cmd("startinsert")
    end
  else
    pcall(
      vim.api.nvim_win_set_cursor,
      win,
      { row, math.min(target, math.max(#line - 1, 0)) }
    )
  end
end

-- Prompt for a label, insert `[label]` at the cursor, prompt for a URL, then
-- create the `[label]: url` definition under `# References/Notes`
---@param mode string "n" or "i", the mode the binding was triggered from
M.insert = function(mode)
  mode = mode or "n"
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row, col = cursor[1], cursor[2]

  vim.ui.input({ prompt = "Reference label: " }, function(label)
    if not label or label == "" then
      place_after_marker(win, bufnr, row, col, 0, mode)
      return
    end

    local marker = ("[%s]"):format(label)
    vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { marker })

    vim.ui.input({ prompt = marker .. ": " }, function(url)
      if url == nil then
        -- canceled, keep the inline marker but do not create a definition
        place_after_marker(win, bufnr, row, col, #marker, mode)
        return
      end

      local def = M.find_definition(bufnr, label)
      if def then
        vim.notify(
          ("Reference [%s] already defined on line %d"):format(label, def.lnum),
          vim.log.levels.WARN
        )
      else
        M.insert_definition(bufnr, label, url)
      end

      place_after_marker(win, bufnr, row, col, #marker, mode)
    end)
  end)
end

return M
