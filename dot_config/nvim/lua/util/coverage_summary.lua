--- The coverage summary window

local Snacks = require("snacks")
local coverage = require("util.coverage")

local M = {}

local ns = vim.api.nvim_create_namespace("coverage-summary")

-- worst first
local sorts =
  { "lines", "branches", "regions", "methods", "uncovered", "dead", "name" }

local view = {
  --- roll the files up under the assembly they were compiled into
  grouped = false,
  sort = "lines",
  --- worst first
  descending = false,
  filter = "",
  uncovered_only = false,
  dead_only = false,
  generated = false,
  --- @type any
  win = nil,
  --- @type table<integer, string> buffer line to file path
  lines = {},
}

--- the first row of the table
local HEADER = 4
local BAR = 12

--- @param metric CoverageMetric
--- @return number? nil when the report says nothing, not zero
local function percent(metric)
  if metric.total == 0 then
    return nil
  end
  return metric.covered / metric.total * 100
end

--- @param pct number?
--- @return string
local function hl_for(pct)
  if not pct then
    return "Comment"
  end
  if pct >= 80 then
    return "CoverageCovered"
  end
  if pct >= 50 then
    return "CoveragePartial"
  end
  return "CoverageUncovered"
end

--- @param pct number?
--- @return string
local function pct_text(pct)
  return pct and ("%5.1f%%"):format(pct) or "     -"
end

--- @param chunks table[] {text, hl?}
--- @return string, table[]
local function assemble(chunks)
  local text, marks = "", {}
  for _, chunk in ipairs(chunks) do
    local from = #text
    text = text .. chunk[1]
    if chunk[2] and #chunk[1] > 0 then
      marks[#marks + 1] = { from, #text, chunk[2] }
    end
  end
  return text, marks
end

--- noise: generated code, and source that is not even in the project, a nuget
--- package can ship .cs contentFiles into the build and coverlet reports them
--- like any other source
--- @param rel string
--- @param external boolean
--- @return boolean
local function noise(rel, external)
  local config = coverage.config
  if external and config.summary_hide_external then
    return true
  end
  -- the patterns are written "/target/" so that they cannot catch a directory
  -- merely ending in one, which leaves them unable to match a path that starts
  -- with it, and cargo's target/ sits at the workspace root. Match against the
  -- rooted path so a top level directory reads the same as a nested one
  local path = "/" .. rel
  for _, pattern in ipairs(config.summary_exclude) do
    if path:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

--- @return table[]
local function collect()
  local root = coverage.root()
  local groups = coverage.group_data()
  local rows = {}

  for _, path in ipairs(coverage.paths()) do
    local rel, external = path, true
    if root and path:sub(1, #root + 1) == root .. "/" then
      rel, external = path:sub(#root + 2), false
    end

    local stats = coverage.file_stats(path)
    local row = {
      path = path,
      rel = rel,
      group = groups[path] or "(no assembly)",
      stats = stats,
      uncovered = stats.lines.total - stats.lines.covered,
      dead = stats.methods.total - stats.methods.covered,
      noise = noise(rel, external),
    }

    local keep = view.generated or not row.noise
    if keep and view.filter ~= "" then
      keep = rel:lower():find(view.filter:lower(), 1, true) ~= nil
    end
    if keep and view.uncovered_only then
      keep = row.uncovered > 0
    end
    if keep and view.dead_only then
      keep = row.dead > 0
    end

    if keep then
      rows[#rows + 1] = row
    end
  end

  --- ascending is worst first, which is a low percentage but a high count, so
  --- the counts are negated to make the two directions read the same way
  ---
  --- a file with no branches at all should not outrank one at 0%
  local function key(row)
    if view.sort == "name" then
      return nil
    end
    if view.sort == "uncovered" then
      return -row.uncovered
    end
    if view.sort == "dead" then
      return -row.dead
    end
    return percent(row.stats[view.sort]) or math.huge
  end

  table.sort(rows, function(a, b)
    if view.sort == "name" then
      if view.descending then
        return b.rel < a.rel
      end
      return a.rel < b.rel
    end
    local ka, kb = key(a), key(b)
    if ka == kb then
      return a.rel < b.rel
    end
    if view.descending then
      return ka > kb
    end
    return ka < kb
  end)

  return rows
end

--- @param pct number?
--- @return table[]
local function bar(pct)
  if not pct then
    return { { (" "):rep(BAR) } }
  end
  local filled = math.floor(pct / 100 * BAR + 0.5)
  filled = math.max(0, math.min(BAR, filled))
  return {
    { ("█"):rep(filled), hl_for(pct) },
    { ("█"):rep(BAR - filled), "CoverageUncovered" },
  }
end

--- the totals reflect the visible rows in the summary
--- @param rows table[]
--- @return CoverageStats
local function totals(rows)
  local sum = {
    lines = { covered = 0, total = 0 },
    branches = { covered = 0, total = 0 },
    regions = { covered = 0, total = 0 },
    methods = { covered = 0, total = 0 },
  }
  for _, row in ipairs(rows) do
    for _, key in ipairs({ "lines", "branches", "regions", "methods" }) do
      sum[key].covered = sum[key].covered + row.stats[key].covered
      sum[key].total = sum[key].total + row.stats[key].total
    end
  end
  return sum
end

local function render()
  local win = view.win
  if not win or not win:buf_valid() then
    return
  end
  local buf = win.buf
  -- buf_valid() above already guarantees it
  ---@cast buf integer

  local rows = collect()
  local width = 30
  for _, row in ipairs(rows) do
    width = math.max(width, #row.rel + (view.grouped and 2 or 0))
  end
  width = math.min(width, 70)

  local total = totals(rows)
  local lines, marks = {}, {}

  local function push(chunks)
    local text, chunk_marks = assemble(chunks)
    lines[#lines + 1] = text
    marks[#lines] = chunk_marks
  end

  -- the whole unfiltered project
  push({
    { "  " },
    { "lines ", "Comment" },
    { pct_text(percent(total.lines)), hl_for(percent(total.lines)) },
    {
      (" (%d/%d)   "):format(total.lines.covered, total.lines.total),
      "Comment",
    },
    { "branches ", "Comment" },
    { pct_text(percent(total.branches)), hl_for(percent(total.branches)) },
    {
      (" (%d/%d)   "):format(total.branches.covered, total.branches.total),
      "Comment",
    },
    { "regions ", "Comment" },
    { pct_text(percent(total.regions)), hl_for(percent(total.regions)) },
    {
      (" (%d/%d)   "):format(total.regions.covered, total.regions.total),
      "Comment",
    },
    { "methods ", "Comment" },
    { pct_text(percent(total.methods)), hl_for(percent(total.methods)) },
    {
      (" (%d/%d)"):format(total.methods.covered, total.methods.total),
      "Comment",
    },
  })

  local flags = {}
  if view.filter ~= "" then
    flags[#flags + 1] = ("filter %q"):format(view.filter)
  end
  if view.uncovered_only then
    flags[#flags + 1] = "uncovered only"
  end
  if view.dead_only then
    flags[#flags + 1] = "dead methods only"
  end
  if view.grouped then
    flags[#flags + 1] = "grouped by assembly"
  end
  flags[#flags + 1] = view.generated and "noise shown" or "noise hidden"

  push({
    { "  " },
    {
      ("%d files  ·  sort %s %s  ·  %s"):format(
        #rows,
        view.sort,
        view.descending and "↓" or "↑",
        table.concat(flags, "  ·  ")
      ),
      "Comment",
    },
  })

  push({ { "" } })

  push({
    {
      ("  %-" .. width .. "s  %-" .. BAR .. "s  %6s  %6s  %6s  %6s  %5s  %5s"):format(
        "FILE",
        "COVERAGE",
        "LINES",
        "BRANCH",
        "REGION",
        "METHOD",
        "UNCOV",
        "DEAD"
      ),
      "Title",
    },
  })

  --- one table row grouped with a file or the assembly heading
  --- @param label string
  --- @param stats CoverageStats
  --- @param uncovered integer
  --- @param dead integer
  --- @param label_hl string?
  local function row_chunks(label, stats, uncovered, dead, label_hl)
    local pct = percent(stats.lines)
    if #label > width then
      label = "…" .. label:sub(#label - width + 2)
    end

    local chunks = {
      { "  " },
      { ("%-" .. width .. "s"):format(label), label_hl },
      { "  " },
    }
    vim.list_extend(chunks, bar(pct))
    vim.list_extend(chunks, {
      { "  " },
      { pct_text(pct), hl_for(pct) },
      { "  " },
      {
        pct_text(percent(stats.branches)),
        hl_for(percent(stats.branches)),
      },
      { "  " },
      {
        pct_text(percent(stats.regions)),
        hl_for(percent(stats.regions)),
      },
      { "  " },
      {
        pct_text(percent(stats.methods)),
        hl_for(percent(stats.methods)),
      },
      {
        ("  %5d"):format(uncovered),
        uncovered > 0 and "CoverageUncovered" or "Comment",
      },
      {
        ("  %5d"):format(dead),
        dead > 0 and "CoverageMethodUncovered" or "Comment",
      },
    })
    return chunks
  end

  view.lines = {}

  if view.grouped then
    -- group the files up under the assembly they were compiled into
    local assemblies, order = {}, {}
    for _, row in ipairs(rows) do
      if not assemblies[row.group] then
        assemblies[row.group] = {}
        order[#order + 1] = row.group
      end
      table.insert(assemblies[row.group], row)
    end
    table.sort(order)

    for index, name in ipairs(order) do
      local members = assemblies[name]
      if index > 1 then
        push({ { "" } })
      end

      local sum = totals(members)
      local uncovered, dead = 0, 0
      for _, row in ipairs(members) do
        uncovered, dead = uncovered + row.uncovered, dead + row.dead
      end
      push(
        row_chunks(
          ("%s (%d)"):format(name, #members),
          sum,
          uncovered,
          dead,
          "Title"
        )
      )

      for _, row in ipairs(members) do
        push(row_chunks("  " .. row.rel, row.stats, row.uncovered, row.dead))
        view.lines[#lines] = row.path
      end
    end
  else
    for _, row in ipairs(rows) do
      push(row_chunks(row.rel, row.stats, row.uncovered, row.dead))
      view.lines[#lines] = row.path
    end
  end

  if #rows == 0 then
    push({ { "  nothing matches", "Comment" } })
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for lnum, chunk_marks in pairs(marks) do
    for _, mark in ipairs(chunk_marks) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, mark[1], {
        end_col = mark[2],
        hl_group = mark[3],
      })
    end
  end

  -- ensure the cursor is always on a row
  local cursor = vim.api.nvim_win_get_cursor(win.win)
  local target = math.max(HEADER + 1, math.min(cursor[1], #lines))
  pcall(vim.api.nvim_win_set_cursor, win.win, { target, 0 })
end

local function open_file()
  local win = view.win
  if not win then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(win.win)[1]
  local path = view.lines[lnum]
  if not path then
    return
  end

  local first = coverage.first_uncovered(path)
  win:close()

  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  coverage.show_buffer(buf)
  if first then
    pcall(vim.api.nvim_win_set_cursor, 0, { first, 0 })
    vim.cmd("normal! zz")
  end
end

local function prompt_filter()
  vim.ui.input(
    { prompt = "Filter files: ", default = view.filter },
    function(input)
      if input == nil then
        return
      end
      view.filter = input
      render()
    end
  )
end

local function cycle_sort(step)
  local index = 1
  for i, name in ipairs(sorts) do
    if name == view.sort then
      index = i
    end
  end
  view.sort = sorts[(index - 1 + step) % #sorts + 1]
  render()
end

function M.open()
  coverage.resolve()
  if not coverage.is_loaded() then
    coverage.load({ activate = false, notify = false })
    if not coverage.is_loaded() then
      return vim.notify("coverage: no report found", vim.log.levels.WARN)
    end
  end

  if view.win and view.win:valid() then
    view.win:focus()
    return
  end

  view.win = Snacks.win({
    title = " Coverage ",
    title_pos = "center",
    footer = " ⏎ open   / filter   s sort   S reverse   A assembly   u uncovered   d dead   g noise   a reset   r reload   q close ",
    footer_pos = "center",
    border = "rounded",
    width = 0.85,
    height = 0.8,
    enter = true,
    minimal = true,
    wo = {
      cursorline = true,
      number = false,
      relativenumber = false,
      signcolumn = "no",
      statuscolumn = "",
      wrap = false,
    },
    bo = {
      filetype = "coverage-summary",
      modifiable = false,
      buftype = "nofile",
    },
    keys = {
      q = "close",
      ["<Esc>"] = "close",
      ["<CR>"] = open_file,
      ["/"] = prompt_filter,
      s = function()
        cycle_sort(1)
      end,
      S = function()
        view.descending = not view.descending
        render()
      end,
      A = function()
        view.grouped = not view.grouped
        render()
      end,
      u = function()
        view.uncovered_only = not view.uncovered_only
        render()
      end,
      d = function()
        view.dead_only = not view.dead_only
        render()
      end,
      g = function()
        view.generated = not view.generated
        render()
      end,
      a = function()
        view.filter = ""
        view.uncovered_only = false
        view.dead_only = false
        view.generated = false
        render()
      end,
      r = function()
        -- the summary's own buffer is a scratch buffer, so the root has to be
        -- carried over rather than resolved from it
        coverage.load({
          activate = false,
          notify = false,
          root = coverage.root(),
        })
        render()
      end,
    },
  })

  render()
end

return M
