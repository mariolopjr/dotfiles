--- Everything an open hover float does beyond showing text: the link map
--- laid over stripped targets, the buffer keymaps that act on it, and the
--- history a peek pushes
---
--- Keys, bound to the float buffer:
---   gd     follow the reference under the cursor to its definition.
---          rustdoc urls map back onto source, other urls open in the
---          browser, as does a rustdoc page that resolves nowhere locally
---   K      peek the reference in place, the float re-renders on its hover
---   <C-o>  back to the hover the peek replaced
---   gx     open a url reference in the browser
---   q      close the float
---
--- Stripped link targets come back as one extmark per label, cursor lookup
--- reads the extmark under the cursor and prose falls back to the
--- path-shaped word there. Peeking works because servers answer hover and
--- documentSymbol on files never opened in the editor, the reply runs
--- through the same tidy and decorate pipeline into the same float

local M = {}

local decorate = require("hoverboard.decorate")
local resolve = require("hoverboard.resolve")
local synth = require("hoverboard.synth")
local tidy = require("hoverboard.tidy")

local ns = vim.api.nvim_create_namespace("hoverboard_links")

--- state per float buffer, the history survives re-renders of the same
--- float and ends when the float closes
--- @type table<integer, { client: vim.lsp.Client?, raw: string[], params: table?, targets: table<integer, string>, history: { raw: string[], params: table?, cursor: integer[] }[], max_width: integer, win: integer }>
local floats = {}

--- The link target under the cursor, read off the extmarks so header
--- splices that moved the text moved the map with it
--- @param buf integer
--- @return string?
local function target_at(buf)
  local state = floats[buf]
  if not state then
    return nil
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    ns,
    { row - 1, 0 },
    { row - 1, -1 },
    { details = true }
  )
  for _, m in ipairs(marks) do
    if col >= m[3] and col < (m[4].end_col or m[3]) then
      return state.targets[m[1]]
    end
  end
  return nil
end

--- The path-shaped word under the cursor, for prose references that carry
--- no link target
--- @return string?
local function word_at()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  for s, word in line:gmatch("()([%w_:]+)") do
    if s - 1 <= col and col < s - 1 + #word then
      local trimmed = word:gsub("^:+", ""):gsub(":+$", "")
      return trimmed ~= "" and trimmed or nil
    end
  end
  return nil
end

--- @param win integer
local function close(win)
  if
    vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_config(win).relative ~= ""
  then
    vim.api.nvim_win_close(win, true)
  end
end

--- Compact origin and relative tail for a location, the absolute paths of
--- registry, toolchain and generated sources all look alike in a picker
--- @param fname string
--- @param root string? workspace root of the origin client
--- @return string origin
--- @return string tail
local function describe(fname, root)
  local crate, rest = fname:match("/registry/src/[^/]+/([^/]+)/(.+)$")
  if crate then
    return crate, rest
  end
  local lib
  lib, rest = fname:match("/rustlib/src/rust/library/([^/]+)/(.+)$")
  if lib then
    return lib, rest
  end
  local pkg
  pkg, rest = fname:match("/build/([^/]+)%-[0-9a-f]+/out/(.+)$")
  if pkg then
    return pkg .. " (generated)", rest
  end
  if root and root ~= "" and fname:sub(1, #root + 1) == root .. "/" then
    return vim.fn.fnamemodify(root, ":t"), fname:sub(#root + 2)
  end
  return "", vim.fn.fnamemodify(fname, ":~")
end

--- One location goes straight through, several are offered as a choice
--- rather than guessed at. snacks draws the picker with a preview of each
--- candidate. If snacks is not available, vim.ui.select is used instead
--- @param locs { uri: string, range: table }[]
--- @param root string?
--- @param cb fun(loc: { uri: string, range: table })
local function choose(locs, root, cb)
  if #locs == 1 then
    return cb(locs[1])
  end

  local width = 0
  local items = {}
  for i, loc in ipairs(locs) do
    local fname = vim.uri_to_fname(loc.uri)
    local origin, tail = describe(fname, root)
    width = math.max(width, #origin)
    -- loc is a reserved snacks item field with its own resolution rules,
    -- the raw location rides along as location instead
    items[i] = {
      idx = i,
      location = loc,
      origin = origin,
      tail = ("%s:%d"):format(tail, loc.range.start.line + 1),
      file = fname,
      pos = { loc.range.start.line + 1, loc.range.start.character },
    }
    items[i].text = origin .. " " .. items[i].tail
  end

  local ok, picker = pcall(require, "snacks.picker")
  if not ok or type(picker.pick) ~= "function" then
    vim.ui.select(items, {
      prompt = "Definition",
      format_item = function(item)
        return item.origin == "" and item.tail
          or item.origin .. "  " .. item.tail
      end,
    }, function(item)
      if item then
        cb(item.location)
      end
    end)
    return
  end

  picker.pick({
    source = "hoverboard",
    title = "Definition",
    items = items,
    format = function(item)
      return {
        { ("%-" .. width .. "s"):format(item.origin), "SnacksPickerDir" },
        { "  " },
        { item.tail, "SnacksPickerFile" },
      }
    end,
    preview = "file",
    confirm = function(p, item)
      p:close()
      if item then
        vim.schedule(function()
          cb(item.location)
        end)
      end
    end,
  })
end

--- Resolve the reference under the cursor down to one location, member
--- resolution included, urls short-circuit to the browser
--- @param buf integer
--- @param cb fun(loc: { uri: string, range: table })
local function locate(buf, cb)
  local target = target_at(buf) or word_at()
  if not target then
    return
  end
  local url
  if resolve.is_url(target) then
    -- a rustdoc url maps back onto source, anything else routes to the browser
    local path = resolve.from_url(target)
    if not path then
      vim.ui.open(target)
      return
    end
    url, target = target, path
  end
  local state = floats[buf]
  local client = state and state.client
  if not client then
    return
  end
  resolve.resolve(client, target, function(locs, member, anchor)
    if #locs == 0 then
      -- nowhere to jump locally, open in browser
      if url then
        vim.ui.open(url)
      else
        vim.notify(
          "hoverboard: " .. target .. " did not resolve",
          vim.log.levels.INFO
        )
      end
      return
    end
    choose(locs, client.root_dir, function(loc)
      if member then
        resolve.member(client, loc, anchor, member, cb)
      else
        cb(loc)
      end
    end)
  end)
end

--- gd: close the float and jump to the definition, through the jumplist
--- @param buf integer
function M.follow(buf)
  local state = floats[buf]
  locate(buf, function(loc)
    close(state.win)
    vim.cmd("normal! m'")
    vim.lsp.util.show_document(
      { uri = loc.uri, range = loc.range },
      state.client.offset_encoding,
      { reuse_win = true, focus = true }
    )
  end)
end

--- Client, params and history the wrapper consumes instead of deriving
--- them from the cursor
--- @type { client: vim.lsp.Client, params: table, history: table[] }?
M.handoff = nil

--- K: replace what the float shows with the reference's own hover
--- @param buf integer
function M.peek(buf)
  local state = floats[buf]
  local from = vim.api.nvim_win_get_cursor(0)
  locate(buf, function(loc)
    local params =
      { textDocument = { uri = loc.uri }, position = loc.range.start }
    state.client:request("textDocument/hover", params, function(err, result)
      if err or not result or not result.contents then
        vim.notify("hoverboard: nothing to show there", vim.log.levels.INFO)
        return
      end
      local raw = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
      if #raw == 0 then
        return
      end
      state.history[#state.history + 1] =
        { raw = state.raw, params = state.params, cursor = from }

      if
        vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(state.win)
      then
        M.render(buf, state.win, raw, state.client, params)
        return
      end

      M.handoff =
        { client = state.client, params = params, history = state.history }
      local _, win = vim.lsp.util.open_floating_preview(raw, "markdown", {
        focus_id = "textDocument/hover",
      })
      M.handoff = nil
      -- the reader was mid navigation, keep them in the float
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
      end
    end)
  end)
end

--- <C-o>: back to the hover and cursor position the last peek replaced
--- @param buf integer
function M.back(buf)
  local state = floats[buf]
  if not state or #state.history == 0 then
    return
  end
  local entry = table.remove(state.history)
  M.render(buf, state.win, entry.raw, state.client, entry.params, entry.cursor)
end

--- gx: a url reference opens in the browser
--- @param buf integer
function M.open(buf)
  local target = target_at(buf)
  if target and resolve.is_url(target) then
    vim.ui.open(target)
  end
end

--- @param buf integer
local function bind(buf)
  if vim.b[buf].hoverboard_bound then
    return
  end
  vim.b[buf].hoverboard_bound = true
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, function()
      fn(buf)
    end, { buffer = buf, nowait = true, desc = desc })
  end
  map("gd", M.follow, "Follow the reference under the cursor")
  map("K", M.peek, "Peek the reference under the cursor")
  map("<C-o>", M.back, "Back to the previous hover")
  map("gx", M.open, "Open the reference in the browser")
  map("q", function()
    close(vim.api.nvim_get_current_win())
  end, "Close the hover")

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      floats[buf] = nil
    end,
  })
end

--- Tidied rows mapped onto the rows the float actually shows: the native
--- float normalizes its markdown, dropping blank lines around separators
--- and expanding them to rules, so link rows re-anchor by walking both
--- line sets in order
--- @param tidied string[]
--- @param shown string[]
--- @return table<integer, integer> tidied row to shown row, 1 based
local function row_map(tidied, shown)
  local function is_rule(line)
    return line ~= "" and line:gsub("─", "") == ""
  end
  local map = {}
  local b = 1
  for t = 1, #tidied do
    local line = tidied[t]
    local cur = shown[b]
    if cur == nil then
      break
    end
    local sep = vim.trim(line):match("^[-_*][-_*][-_*]+$") ~= nil
      or is_rule(line)
    if line == cur or (sep and is_rule(cur)) then
      map[t] = b
      b = b + 1
    elseif vim.trim(line) ~= "" then
      -- an unknown transform, stop mapping rather than guess
      break
    end
  end
  return map
end

--- Wire a newly filled float: buffer variables the decorator reads, the
--- decoration itself, the link map, keymaps and the async header synthesis
--- @param buf integer
--- @param win integer
--- @param ctx { raw: string[], lines: string[]?, client: vim.lsp.Client?, params: table?, links: table[]?, table_marks: table?, lang: string?, pending: table?, max_width: integer?, history: table[]? }
function M.populate(buf, win, ctx)
  vim.b[buf].hover_server = ctx.client and ctx.client.name or nil
  vim.b[buf].hover_lang = ctx.lang
  vim.b[buf].hover_table_marks = ctx.table_marks
  vim.b[buf].hover_max_width = ctx.max_width or 90
  decorate.decorate(buf, win)

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local map =
    row_map(ctx.lines or {}, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  local targets = {}
  for _, l in ipairs(ctx.links or {}) do
    local row = map[l.row]
    if row then
      local ok, id =
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, l.scol, {
          end_col = l.ecol,
          hl_group = "HoverLink",
          priority = 105,
        })
      if ok then
        targets[id] = l.target
      end
    end
  end

  local previous = floats[buf]
  floats[buf] = {
    client = ctx.client,
    raw = ctx.raw,
    params = ctx.params,
    targets = targets,
    history = ctx.history or previous and previous.history or {},
    max_width = ctx.max_width or 90,
    win = win,
  }
  bind(buf)

  if ctx.pending and ctx.client and ctx.params then
    synth.synthesize(
      buf,
      win,
      ctx.client,
      ctx.params,
      floats[buf].max_width,
      ctx.pending
    )
  end
end

--- Replace what an open float shows and run the full pipeline over it
--- @param buf integer
--- @param win integer
--- @param raw string[] hover markdown as the server sent it
--- @param client vim.lsp.Client
--- @param params table position params behind raw, header synthesis reuses them
--- @param cursor integer[]? restored instead of the top for a back step
function M.render(buf, win, raw, client, params, cursor)
  local lines, table_marks, links = tidy.tidy(vim.list_slice(raw))
  local lang = tidy.fragment_lang(lines)
  local pending
  if client and client.name == "rust-analyzer" then
    lines, pending = synth.apply_cached(lines, links)
  end

  -- match what open_floating_preview showed. Rules expand to the width the
  -- float is about to fit, the window's own width still reflects the
  -- previous hover
  local max_width = floats[buf] and floats[buf].max_width or 90
  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local shown = lines
  if vim.lsp.util._normalize_markdown then
    shown = vim.lsp.util._normalize_markdown(
      vim.list_slice(lines),
      { width = math.min(width, max_width) }
    )
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, shown)
  vim.bo[buf].modifiable = false
  decorate.refit_width(win, shown, max_width)
  pcall(vim.api.nvim_win_set_cursor, win, cursor or { 1, 0 })

  M.populate(buf, win, {
    raw = raw,
    lines = lines,
    client = client,
    params = params,
    links = links,
    table_marks = table_marks,
    lang = lang,
    pending = pending,
    max_width = max_width,
  })
end

return M
