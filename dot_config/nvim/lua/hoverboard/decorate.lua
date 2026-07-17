--- Extmark styling of an open hover float, on top of the native treesitter
--- markdown rendering
---
--- The float already highlights fenced code through language injections and
--- conceals inline markup. Decorating hides the fence lines, bands and pads
--- doc body code blocks, leaves the signature panel on the plain float
--- background with its crate path dimmed, gives inline code a chip
--- background, draws list bullets, flattens headings to bold text, boxes
--- pipe tables in border glyphs, recolors thematic breaks and conceals
--- heading markers

local M = {}

local ns = vim.api.nvim_create_namespace("hoverboard")

--- @type table<string, vim.treesitter.Query|false>
local queries = {}

--- @param lang string
--- @param text string
--- @return vim.treesitter.Query?
function M.get_query(lang, text)
  if queries[lang] == nil then
    local ok, parsed = pcall(vim.treesitter.query.parse, lang, text)
    queries[lang] = ok and parsed or false
  end
  return queries[lang] or nil
end

local block_query = [[
  (fenced_code_block (code_fence_content) @code)
  (fenced_code_block_delimiter) @fence
  [
    (atx_h1_marker) (atx_h2_marker) (atx_h3_marker)
    (atx_h4_marker) (atx_h5_marker) (atx_h6_marker)
  ] @marker
  [
    (list_marker_minus) (list_marker_star) (list_marker_plus)
  ] @bullet
  (pipe_table) @table
  (pipe_table_delimiter_row) @tdelim
  (pipe_table_header) @trow
  (pipe_table_row) @trow
]]

local chip_query = "(code_span) @chip"

--- Color a flattened cell code span as source of the hover's language.
--- Fragments parse with enough convention for types, builtins and
--- attributes, anything the highlight queries cannot classify stays plain
--- @param buf integer
--- @param row integer
--- @param scol integer byte offset of the span in its line
--- @param text string
--- @param lang string
local function fragment(buf, row, scol, text, lang)
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, lang)
  local tree = ok and parser and parser:parse()[1]
  local okq, hq = pcall(vim.treesitter.query.get, lang, "highlights")
  if not tree or not okq or not hq then
    return
  end
  for id, node in hq:iter_captures(tree:root(), text) do
    local capture = hq.captures[id]
    local nsrow, nscol, nerow, necol = node:range()
    if
      nsrow == 0
      and nerow == 0
      and nscol < necol
      and capture ~= "spell"
      and capture ~= "nospell"
      and capture:sub(1, 1) ~= "_"
    then
      -- equal priority, later captures win, matching query precedence
      vim.api.nvim_buf_set_extmark(buf, ns, row, scol + nscol, {
        end_col = scol + necol,
        hl_group = "@" .. capture .. "." .. lang,
        priority = 95,
      })
    end
  end
end

--- Fit the float's width to its longest line
--- @param win integer
--- @param lines string[]
--- @param max_width integer
function M.refit_width(win, lines, max_width)
  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  vim.api.nvim_win_set_config(win, {
    width = math.min(width, max_width or 90),
  })
end

--- @param buf integer
--- @param win integer
function M.decorate(buf, win)
  local q = M.get_query("markdown", block_query)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not q or not ok or not parser then
    return
  end
  -- parse injections too, the inline chips live in the markdown_inline tree
  local tree = parser:parse(true)[1]
  if not tree then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  --- @type { srow: integer, erow: integer }[]
  local blocks = {}
  --- @type { srow: integer, erow: integer }[]
  local tables = {}
  --- @type integer[]
  local tdelims = {}
  --- @type integer[]
  local trows = {}
  for id, node in q:iter_captures(tree:root(), buf) do
    local capture = q.captures[id]
    local srow, scol, erow, ecol = node:range()
    if capture == "code" then
      -- an end col of 0 means the content node closed on the fence line
      blocks[#blocks + 1] =
        { srow = srow, erow = ecol == 0 and erow - 1 or erow }
    elseif capture == "fence" then
      -- the bundled markdown queries carry conceal_lines for fence rows but
      -- the highlighter does not reliably apply it in floats
      vim.api.nvim_buf_set_extmark(buf, ns, srow, 0, {
        conceal_lines = "",
      })
    elseif capture == "marker" then
      -- marker plus the space that follows it, and flatten the heading text
      -- to a single style
      vim.api.nvim_buf_set_extmark(buf, ns, srow, 0, {
        end_col = ecol + 1,
        conceal = "",
      })
      vim.api.nvim_buf_set_extmark(buf, ns, srow, 0, {
        end_col = #lines[srow + 1],
        hl_group = "HoverHeading",
      })
    elseif capture == "bullet" then
      -- the marker node spans the trailing space too, conceal only the
      -- marker char so the bullet keeps its gap
      vim.api.nvim_buf_set_extmark(buf, ns, srow, scol, {
        end_col = scol + 1,
        conceal = "•",
      })
    elseif capture == "table" then
      tables[#tables + 1] =
        { srow = srow, erow = ecol == 0 and erow - 1 or erow }
    elseif capture == "tdelim" then
      tdelims[#tdelims + 1] = srow
    elseif capture == "trow" then
      trows[#trows + 1] = srow
    end
  end
  table.sort(blocks, function(a, b)
    return a.srow < b.srow
  end)

  -- inline code chips from the injected markdown_inline trees, background
  -- only so the syntax color stays
  local chips = M.get_query("markdown_inline", chip_query)
  local inline = parser:children()["markdown_inline"]
  if chips and inline then
    for _, itree in pairs(inline:trees()) do
      for _, node in chips:iter_captures(itree:root(), buf) do
        local srow, scol, erow, ecol = node:range()
        vim.api.nvim_buf_set_extmark(buf, ns, srow, scol, {
          end_row = erow,
          end_col = ecol,
          hl_group = "HoverInlineCode",
          priority = 90,
        })
      end
    end
  end

  -- the native float expands thematic breaks into rows of ─, recolor them
  -- ─ is multibyte so a ─+ pattern cannot express "only ─", strip instead
  local rules = {}
  for row, line in ipairs(lines) do
    if line ~= "" and line:gsub("─", "") == "" then
      rules[#rules + 1] = row - 1
      vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
        end_col = #line,
        hl_group = "HoverRule",
      })
    end
  end

  -- tables: pipes become box drawing, the delimiter row a junction row and
  -- virtual lines close the frame. Widths come from the delimiter row, the
  -- only row whose bytes match what renders
  --- @param row string
  --- @param l string
  --- @param m string
  --- @param r string
  --- @return string
  local function junctions(row, l, m, r)
    local parts = {}
    for seg in row:sub(2, -2):gmatch("[^|]+") do
      parts[#parts + 1] = ("─"):rep(#seg)
    end
    return l .. table.concat(parts, m) .. r
  end

  -- tidy marks match tables up by order as long as both sides agree on how
  -- many there are
  table.sort(tables, function(a, b)
    return a.srow < b.srow
  end)
  local lang = vim.b[buf].hover_lang
  local cell_marks = vim.b[buf].hover_table_marks
  if cell_marks and cell_marks.tables ~= #tables then
    cell_marks = nil
  end

  -- unescaped literal pipes in cell text read like separators by bytes,
  -- the tidy pass recorded which byte columns hold structure
  local pipe_cols = {}
  for _, p in ipairs(cell_marks and cell_marks.pipes or {}) do
    local tbl = tables[p.t]
    if tbl then
      pipe_cols[tbl.srow + p.row] = p.cols
    end
  end

  for _, row in ipairs(trows) do
    local cols = pipe_cols[row]
    if cols then
      for _, col in ipairs(cols) do
        vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
          virt_text = { { "│", "HoverTableBorder" } },
          virt_text_pos = "overlay",
        })
      end
    else
      local line = lines[row + 1] or ""
      for pos in line:gmatch("()|") do
        vim.api.nvim_buf_set_extmark(buf, ns, row, pos - 1, {
          virt_text = { { "│", "HoverTableBorder" } },
          virt_text_pos = "overlay",
        })
      end
    end
  end
  for _, row in ipairs(tdelims) do
    local line = lines[row + 1] or ""
    if line:match("^|.*|$") then
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        virt_text = {
          { junctions(line, "├", "┼", "┤"), "HoverTableBorder" },
        },
        virt_text_pos = "overlay",
      })
    end
  end
  -- reapply the cell styling the tidy pass flattened away. Code spans
  -- additionally color as hover-language source where the fragment parses
  -- into something the highlight queries recognize
  if cell_marks then
    for _, s in ipairs(cell_marks.spans) do
      local tbl = tables[s.t]
      if tbl and s.code then
        local row = tbl.srow + s.row
        vim.api.nvim_buf_set_extmark(buf, ns, row, s.scol, {
          end_col = s.ecol,
          hl_group = "HoverInlineCode",
          priority = 90,
        })
        if lang then
          fragment(
            buf,
            row,
            s.scol,
            (lines[row + 1] or ""):sub(s.scol + 1, s.ecol),
            lang
          )
        end
      end
      if tbl and s.bold then
        vim.api.nvim_buf_set_extmark(buf, ns, tbl.srow + s.row, s.scol, {
          end_col = s.ecol,
          hl_group = "HoverBold",
          priority = 95,
        })
      end
    end
  end

  for _, tbl in ipairs(tables) do
    -- header, delimiter, rows: the delimiter always sits one below the top
    local delim = lines[tbl.srow + 2] or ""
    if delim:match("^|.*|$") then
      vim.api.nvim_buf_set_extmark(buf, ns, tbl.srow, 0, {
        virt_lines = {
          { { junctions(delim, "┌", "┬", "┐"), "HoverTableBorder" } },
        },
        virt_lines_above = true,
      })
      vim.api.nvim_buf_set_extmark(buf, ns, tbl.erow, 0, {
        virt_lines = {
          { { junctions(delim, "└", "┴", "┘"), "HoverTableBorder" } },
        },
      })
    end
  end

  -- the signature panel reads as the float's header, only code below the
  -- rule that closes it gets the band. Without such a rule there is no doc
  -- body and the first block alone is the header
  --- @type table<integer, boolean> rows carrying the two cell band pad
  local banded = {}
  if #blocks > 0 then
    local header = blocks[1]
    local header_end = header.erow
    for _, row in ipairs(rules) do
      if row > header.srow then
        header_end = row
        break
      end
    end
    for _, block in ipairs(blocks) do
      if block.srow > header_end then
        for row = block.srow, block.erow do
          banded[row] = true
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            line_hl_group = "HoverCodeBlock",
          })
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            virt_text = { { "  ", "HoverCodeBlock" } },
            virt_text_pos = "inline",
          })
        end
      end
    end

    -- a multi-line header opening with a path-shaped line carries the
    -- defining crate above the signature, dim it
    local path = lines[header.srow + 1]
    if header.erow > header.srow and path and not path:find("%s") then
      vim.api.nvim_buf_set_extmark(buf, ns, header.srow, 0, {
        end_col = #path,
        hl_group = "HoverCratePath",
        priority = 110,
      })
    end
  end

  -- the float was sized to bare line widths before the band pad shifted
  -- code lines two cells right, and before fence rows concealed and table
  -- borders appeared, refit in both directions with width first since it
  -- drives wrapping
  local max_width = vim.b[buf].hover_max_width or 90
  local width = 1
  for row, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line) + (banded[row - 1] and 2 or 0)
    width = math.max(width, w)
  end
  width = math.min(width, max_width)
  if width ~= vim.api.nvim_win_get_width(win) then
    vim.api.nvim_win_set_config(win, { width = width })
  end
  local height = vim.api.nvim_win_text_height(win, {}).all
  if height ~= vim.api.nvim_win_get_height(win) then
    vim.api.nvim_win_set_config(win, {
      height = math.max(1, math.min(height, vim.o.lines - 4)),
    })
  end
end

return M
