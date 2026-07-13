--- Coverage gutters, a toggleable line coverage overlay in the git/sign column
---
--- Parses the following report formats:
---   opencover coverlet
---   cobertura `dotnet test --collect:"XPlat Code Coverage"`
---   go `go test -coverprofile`
---
--- Every report found under the project root is merged, so a solution whose
--- godot tests and libs tests report separately still reads as one picture
---
--- A project can add to the defaults from its own `.nvim.lua`
---
---   vim.g.coverage = {
---     -- hidden from the summary window on top of the built-in noise filters
---     summary_exclude = { "/addons/", "/thirdparty/" },
---     -- searched on top of the default report locations
---     reports = { opencover = { "artifacts/coverage.xml" } },
---   }

local M = {}

local ns = vim.api.nvim_create_namespace("coverage")

--- @class CoverageLine
--- @field hits integer times the line was executed
--- @field btotal integer branch paths on the line
--- @field btaken integer branch paths that were taken

--- @alias CoverageFiles table<string, table<integer, CoverageLine>>

--- methods keyed by the first line the report gives them, true once entered
--- @alias CoverageMethods table<string, table<integer, boolean>>

--- the assembly, module or package a file was compiled into
--- @alias CoverageGroups table<string, string>

--- @class CoverageReport
--- @field files CoverageFiles
--- @field methods CoverageMethods
--- @field groups CoverageGroups

local defaults = {
  -- one glyph per line state with a different color to signify a difference
  -- separate glyph for a method that was never called
  signs = {
    covered = "▎",
    uncovered = "▎",
    partial = "▎",
    method = "󰊕",
  },
  -- mark the methods no test ever entered
  method_signs = true,
  -- spell out the branch count on a partially covered line, "1/2 branches"
  branch_virt_text = true,
  -- below the diagnostic signs so an error still wins the slot
  priority = 5,
  -- tint the line body too, not just the gutter
  line_highlight = true,
  -- how much of the state color is mixed into the line background
  blend = 0.12,
  -- reload when a report is rewritten
  watch = true,
  -- the summary window only shows repo code
  summary_hide_external = true,
  -- exclude generated code
  summary_exclude = { "/obj/", "/bin/", ".g.cs" },
  -- globs searched under the project root and every match is merged
  reports = {
    opencover = {
      "coverage/coverage.xml",
      "coverage/*.opencover.xml",
      "*.opencover.xml",
    },
    cobertura = {
      "coverage/**/coverage.cobertura.xml",
      "**/TestResults/**/coverage.cobertura.xml",
    },
    go = {
      "coverage.out",
      "cover.out",
      "coverage/coverage.out",
    },
  },
}

--- anything setup() was handed, kept apart from the defaults so a project's
--- settings can be re-resolved against them without the two compounding
local overrides = {}

--- the resolved settings, defaults + setup() + the project's own
M.config = vim.deepcopy(defaults)

--- merge `extra` over `base`
---
--- A list is APPENDED to the list it overrides, deduplicated, rather than
--- replacing it. A project adds the filters and the report locations specific to
--- it and inherits the rest. vim.tbl_deep_extend cannot be used here, it merges
--- lists index by index, so a project supplying one exclude would silently keep
--- whatever the defaults happened to hold at indexes 2 and 3
--- @param base table
--- @param extra table?
--- @return table
local function extend(base, extra)
  local out = vim.deepcopy(base)
  for key, value in pairs(extra or {}) do
    if type(value) == "table" and vim.islist(value) then
      local merged, seen = {}, {}
      for _, list in ipairs({ vim.islist(out[key]) and out[key] or {}, value }) do
        for _, item in ipairs(list) do
          if not seen[item] then
            seen[item] = true
            merged[#merged + 1] = item
          end
        end
      end
      out[key] = merged
    elseif type(value) == "table" and type(out[key]) == "table" then
      out[key] = extend(out[key], value)
    else
      out[key] = value
    end
  end
  return out
end

--- defaults, then setup(), then the project, read from vim.g.coverage so
--- an exrc that lands after startup, or on a :cd into another repo, is picked up
--- @return table
function M.resolve()
  M.config = extend(extend(defaults, overrides), vim.g.coverage)
  return M.config
end

-- the gutter glyph
local hlgroups = {
  covered = "CoverageCovered",
  uncovered = "CoverageUncovered",
  partial = "CoveragePartial",
}

-- the line body
local linegroups = {
  covered = "CoverageCoveredLine",
  uncovered = "CoverageUncoveredLine",
  partial = "CoveragePartialLine",
}

-- kept out of the two tables above, a dead method is not a line state and gets
-- no tinted body of its own, the line under it is already red
local method_hl = "CoverageMethodUncovered"

local state = {
  -- a report has been read, independent of whether anything is showing it
  loaded = false,
  -- the project switch, the default for every buffer without an override
  active = false,
  --- @type string?
  root = nil,
  --- @type CoverageFiles
  files = {},
  --- @type CoverageMethods
  methods = {},
  --- @type CoverageGroups
  groups = {},
  --- @type string[]
  reports = {},
  --- the directories a new report can appear in, worked out at load time where
  --- the format of each report is still known
  --- @type string[]
  watch_dirs = {},
  --- @type any[]
  handles = {},
  --- @type any
  timer = nil,
}

--- @param path string
--- @return string?
local function read(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

--- @param path string
--- @return boolean
local function is_absolute(path)
  return path:sub(1, 1) == "/" or path:match("^%a:[\\/]") ~= nil
end

--- @param files CoverageFiles
--- @return CoverageLine
local function record(files, path, lnum)
  local lines = files[path]
  if not lines then
    lines = {}
    files[path] = lines
  end
  local rec = lines[lnum]
  if not rec then
    rec = { hits = 0, btotal = 0, btaken = 0 }
    lines[lnum] = rec
  end
  return rec
end

--- a line's hit count is the strongest signal seen for it, two statements can
--- share a line, and cobertura repeats every line once per method and once per
--- class, neither of which means the line ran twice
local function add_line(files, path, lnum, hits)
  local rec = record(files, path, lnum)
  rec.hits = math.max(rec.hits, hits)
end

--- branch counts are the one thing that does not merge by max, opencover hangs
--- a branch record off every sequence point and several can sit on one line, so
--- within an opencover report they add up, `if (a) f(); else g();` is 2 paths
--- not 1. Cobertura instead states the line's branches once and then repeats the
--- whole line, so there they must not add up
--- @param accumulate boolean
local function add_branch(files, path, lnum, btotal, btaken, accumulate)
  local rec = record(files, path, lnum)
  if accumulate then
    rec.btotal = rec.btotal + btotal
    rec.btaken = rec.btaken + btaken
  else
    rec.btotal = math.max(rec.btotal, btotal)
    rec.btaken = math.max(rec.btaken, btaken)
  end
end

--- @param methods CoverageMethods
local function add_method(methods, path, lnum, visited)
  local entries = methods[path]
  if not entries then
    entries = {}
    methods[path] = entries
  end
  entries[lnum] = entries[lnum] or visited
end

--- fold a parsed report into the loaded set
---
--- hits add up, the same file can be exercised by more than one test run, and a
--- method entered by either run is entered
---
--- branches are the exception, and they are merged conservatively. Cobertura
--- says "1 of 2 paths taken" without saying which path, so when two reports each take
--- a different path out of the same line their union is unknowable and the max
--- is the best that can be claimed. Merged branch coverage is therefore a lower
--- bound on files that more than one report covers
--- @param into CoverageReport
--- @param from CoverageReport
local function merge(into, from)
  for path, lines in pairs(from.files) do
    for lnum, rec in pairs(lines) do
      local cur = record(into.files, path, lnum)
      cur.hits = cur.hits + rec.hits
      cur.btotal = math.max(cur.btotal, rec.btotal)
      cur.btaken = math.max(cur.btaken, rec.btaken)
    end
  end
  for path, entries in pairs(from.methods) do
    for lnum, visited in pairs(entries) do
      add_method(into.methods, path, lnum, visited)
    end
  end
  for path, name in pairs(from.groups) do
    into.groups[path] = into.groups[path] or name
  end
end

--- walk `<tag ...>body</tag>`, tolerating a producer that writes an empty
--- element as `<tag ... />`, which a lazy `(.-)</tag>` capture would let swallow
--- the element that follows
--- @param content string
--- @param tag string
--- @return fun(): string?, string?
local function elements(content, tag)
  local pos = 1
  return function()
    local open_start, open_end, attrs =
      content:find("<" .. tag .. "%s([^>]*)>", pos)
    if not open_start then
      return nil
    end
    if attrs:sub(-1) == "/" then
      pos = open_end + 1
      return attrs, ""
    end
    local close_start, close_end =
      content:find("</" .. tag .. ">", open_end, true)
    local body = content:sub(open_end + 1, (close_start or #content + 1) - 1)
    pos = close_end and close_end + 1 or #content + 1
    return attrs, body
  end
end

--- @param rec CoverageLine
--- @return "covered"|"uncovered"|"partial"
local function classify(rec)
  if rec.hits == 0 then
    return "uncovered"
  end
  if rec.btotal > 0 and rec.btaken < rec.btotal then
    return "partial"
  end
  return "covered"
end

--- opencover nests a per-module file table, so uids are only resolvable within
--- the module that declared them
--- @param content string
--- @return CoverageReport
local function parse_opencover(content)
  local files, methods, groups = {}, {}, {}
  -- a filtered module is written as an empty element, which a lazy
  -- `(.-)</Module>` capture would let swallow the module that follows
  for _, module in elements(content, "Module") do
    local name = module:match("<ModuleName>(.-)</ModuleName>")
    local uids = {}
    for uid, path in module:gmatch('<File uid="(%d+)" fullPath="([^"]*)"') do
      uids[uid] = vim.fs.normalize(path)
      if name then
        groups[uids[uid]] = groups[uids[uid]] or name
      end
    end

    for attrs in module:gmatch("<SequencePoint%s([^>]*)>") do
      local path = uids[attrs:match('fileid="(%d+)"') or ""]
      local hits = tonumber(attrs:match('vc="(%d+)"'))
      local sl = tonumber(attrs:match('sl="(%d+)"'))
      local el = tonumber(attrs:match('el="(%d+)"')) or sl
      if path and hits and sl then
        -- a sequence point can span lines, a multi-line expression is one point
        for lnum = sl, math.max(sl, el) do
          add_line(files, path, lnum, hits)
        end
        -- the branches belong to the line the decision is written on
        local btotal = tonumber(attrs:match('bec="(%d+)"')) or 0
        if btotal > 0 then
          local btaken = tonumber(attrs:match('bev="(%d+)"')) or 0
          add_branch(files, path, sl, btotal, btaken, true)
        end
      end
    end

    -- coverlet writes no `visited` attribute on <Method>, the method's entry
    -- point is the signal, its visit count is the number of times the method was
    -- called. Its `sl` is the first line the method can be anchored to
    for attrs in module:gmatch("<MethodPoint%s([^>]*)>") do
      local path = uids[attrs:match('fileid="(%d+)"') or ""]
      local vc = tonumber(attrs:match('vc="(%d+)"'))
      local sl = tonumber(attrs:match('sl="(%d+)"'))
      if path and vc and sl then
        add_method(methods, path, sl, vc > 0)
      end
    end
  end
  return { files = files, methods = methods, groups = groups }
end

--- cobertura filenames are relative to one of the declared <source> roots
--- @param filename string
--- @param sources string[]
--- @return string
local function resolve_cobertura(filename, sources)
  if is_absolute(filename) then
    return vim.fs.normalize(filename)
  end
  for _, source in ipairs(sources) do
    local path = vim.fs.normalize(source .. "/" .. filename)
    if vim.uv.fs_stat(path) then
      return path
    end
  end
  return vim.fs.normalize((sources[1] or "") .. "/" .. filename)
end

--- @param content string
--- @return CoverageReport
local function parse_cobertura(content)
  local files, methods, groups = {}, {}, {}
  local sources = {}
  for source in content:gmatch("<source>(.-)</source>") do
    sources[#sources + 1] = vim.trim(source)
  end

  -- resolving a filename stats every source root, and a report names the same
  -- file once per class, so resolve each one once
  local resolved = {}

  -- classes hang off a <package>, which is the assembly, a producer that emits
  -- none still has its classes read, just without a group
  local packages = {}
  for attrs, body in elements(content, "package") do
    packages[#packages + 1] =
      { name = attrs:match('name="([^"]*)"'), body = body }
  end
  if #packages == 0 then
    packages = { { body = content } }
  end

  for _, package in ipairs(packages) do
    for attrs, body in elements(package.body, "class") do
      local filename = attrs:match('filename="([^"]*)"')
      if filename then
        local path = resolved[filename]
        if not path then
          path = resolve_cobertura(filename, sources)
          resolved[filename] = path
        end
        if package.name then
          groups[path] = groups[path] or package.name
        end

        -- the class body carries every line twice, once under its method and
        -- once under the class, so these must not accumulate
        for line in body:gmatch("<line%s([^>]*)>") do
          local lnum = tonumber(line:match('number="(%d+)"'))
          local hits = tonumber(line:match('hits="(%d+)"'))
          if lnum and hits then
            add_line(files, path, lnum, hits)
            -- condition-coverage="50% (1/2)"
            local taken, total =
              line:match('condition%-coverage="[^"]*%((%d+)/(%d+)%)"')
            if total then
              add_branch(
                files,
                path,
                lnum,
                tonumber(total),
                tonumber(taken),
                false
              )
            end
          end
        end

        -- a method is entered if any of its lines ran, and it is anchored to
        -- the first line it owns, cobertura states no entry point of its own
        for _, mbody in elements(body, "method") do
          local first, visited = nil, false
          for line in mbody:gmatch("<line%s([^>]*)>") do
            local lnum = tonumber(line:match('number="(%d+)"'))
            local hits = tonumber(line:match('hits="(%d+)"'))
            if lnum and (not first or lnum < first) then
              first = lnum
            end
            if hits and hits > 0 then
              visited = true
            end
          end
          if first then
            add_method(methods, path, first, visited)
          end
        end
      end
    end
  end
  return { files = files, methods = methods, groups = groups }
end

--- every go.mod under the root, longest module path first, so the most specific
--- module wins when resolving a profile entry in a multi-module repo
--- @param root string
--- @return { path: string, dir: string }[]
local function go_modules(root)
  local skip = {
    [".git"] = true,
    ["node_modules"] = true,
    ["vendor"] = true,
    ["bin"] = true,
    ["obj"] = true,
    ["target"] = true,
  }

  local mods = {}
  local iter = vim.fs.dir(root, {
    depth = 4,
    skip = function(dir)
      return not skip[dir]
    end,
  })
  for name, type in iter do
    if type == "file" and vim.fs.basename(name) == "go.mod" then
      local file = vim.fs.normalize(root .. "/" .. name)
      local content = read(file)
      local mod = content and content:match("module%s+(%S+)")
      if mod then
        mods[#mods + 1] = { path = mod, dir = vim.fs.dirname(file) }
      end
    end
  end

  table.sort(mods, function(a, b)
    return #a.path > #b.path
  end)
  return mods
end

--- a go profile addresses files by import path, map it back onto disk
--- @param file string
--- @param mods { path: string, dir: string }[]
--- @param root string
--- @return string? path
--- @return string? module the closest thing go has to an assembly
local function resolve_go(file, mods, root)
  for _, mod in ipairs(mods) do
    if file:sub(1, #mod.path + 1) == mod.path .. "/" then
      return vim.fs.normalize(mod.dir .. "/" .. file:sub(#mod.path + 2)),
        mod.path
    end
  end
  -- a profile written with relative paths, or a module we could not find
  local path = is_absolute(file) and vim.fs.normalize(file)
    or vim.fs.normalize(root .. "/" .. file)
  return vim.uv.fs_stat(path) and path or nil
end

--- a go coverprofile holds block hit counts and nothing else, it carries no
--- branch and no method information, so those stay empty for go
--- @param content string
--- @param root string
--- @return CoverageReport
local function parse_go(content, root)
  local files, groups = {}, {}
  local mods = go_modules(root)
  local resolved = {}

  for line in vim.gsplit(content, "\n", { plain = true }) do
    -- import/path/file.go:12.34,15.6 2 1
    local file, sl, el, hits =
      line:match("^(.*):(%d+)%.%d+,(%d+)%.%d+%s+%d+%s+(%d+)%s*$")
    if file then
      local entry = resolved[file]
      if entry == nil then
        local path, mod = resolve_go(file, mods, root)
        entry = path and { path = path, mod = mod } or false
        resolved[file] = entry
      end
      if entry then
        if entry.mod then
          groups[entry.path] = entry.mod
        end
        for lnum = tonumber(sl), tonumber(el) do
          add_line(files, entry.path, lnum, tonumber(hits))
        end
      end
    end
  end
  return { files = files, methods = {}, groups = groups }
end

local parsers = {
  opencover = parse_opencover,
  cobertura = parse_cobertura,
  go = parse_go,
}

--- @param buf integer?
--- @return string
local function find_root(buf)
  local name = vim.api.nvim_buf_get_name(buf or 0)
  local start = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  local marker = vim.fs.find(function(entry)
    return entry == ".git"
      or entry == "go.mod"
      or entry:match("%.slnx?$") ~= nil
  end, { path = start, upward = true, limit = 1 })[1]
  return marker and vim.fs.dirname(marker)
    or vim.fs.normalize(vim.uv.cwd() --[[@as string]])
end

--- a fresh `dotnet test` writes a whole new guid directory beside the previous
--- run rather than replacing the report in place, so the same test project can
--- be found twice and only its newest run counts.
--- @param paths string[]
--- @param contents table<string, string?>
--- @return string[]
local function newest_per_project(paths, contents)
  local best, order = {}, {}

  for _, path in ipairs(paths) do
    local stat = vim.uv.fs_stat(path)
    local content = contents[path]
    if stat and content then
      local names = {}
      for attrs in content:gmatch("<package%s([^>]*)>") do
        names[#names + 1] = attrs:match('name="([^"]*)"')
      end
      table.sort(names)

      -- a report naming no package at all can only be replaced by another
      -- report written to the same directory
      local id = #names > 0 and table.concat(names, "\0")
        or vim.fs.dirname(path)
      if not best[id] then
        order[#order + 1] = id
        best[id] = { path = path, mtime = stat.mtime.sec }
      elseif stat.mtime.sec > best[id].mtime then
        best[id] = { path = path, mtime = stat.mtime.sec }
      end
    end
  end

  local out = {}
  for _, id in ipairs(order) do
    out[#out + 1] = best[id].path
  end
  table.sort(out)
  return out
end

--- `dotnet test` names each run's results directory after a fresh guid
--- @param dir string
--- @return boolean
local function is_guid_dir(dir)
  return vim.fs.basename(dir):match("^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

--- @param path string
--- @param root string
--- @return boolean
local function within(path, root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

--- @param root string
--- @return table<string, string[]> format to report paths
local function discover(root)
  local found = {}
  for format, globs in pairs(M.config.reports) do
    local paths = {}
    local seen = {}
    for _, glob in ipairs(globs) do
      for _, path in ipairs(vim.fn.glob(root .. "/" .. glob, true, true)) do
        path = vim.fs.normalize(path)
        if not seen[path] then
          seen[path] = true
          paths[#paths + 1] = path
        end
      end
    end
    if #paths > 0 then
      found[format] = paths
    end
  end
  return found
end

-- the nodes a coverage "method" can turn out to be, a lambda and a local
-- function are separate methods in IL and get their own entry in the report, so
-- climbing past them to the enclosing method would hang their result on code
-- that is not theirs
local declarations = {
  -- c_sharp
  method_declaration = true,
  constructor_declaration = true,
  destructor_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
  indexer_declaration = true,
  property_declaration = true,
  event_declaration = true,
  accessor_declaration = true,
  local_function_statement = true,
  lambda_expression = true,
  anonymous_method_expression = true,
  -- go
  function_declaration = true,
  func_literal = true,
}

--- a report anchors a method to its first *coverable* line, which in C# is the
--- opening brace, not the signature. Query treesitter for the declaration that
--- owns that line and use the row its name sits on, which is the signature even
--- when attributes or a multi-line return type push the node's own start higher
--- @param buf integer
--- @param lnum integer 1-based, from the report
--- @return integer 1-based, the report's own line if treesitter cannot say
local function signature_line(buf, lnum)
  local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
  if not line then
    return lnum
  end

  -- the brace sits at the indent, column 0 can land outside the node
  local col = line:find("%S")
  if not col then
    return lnum
  end

  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = buf,
    pos = { lnum - 1, col - 1 },
  })
  if not ok or not node then
    return lnum
  end

  while node do
    if declarations[node:type()] then
      local name = node:field("name")[1]
      return (name or node):start() + 1
    end
    node = node:parent()
  end
  return lnum
end

--- the key a buffer has in the report, if it has one
--- @param buf integer
--- @return string?
local function path_for(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or vim.bo[buf].buftype ~= "" then
    return nil
  end
  local path = vim.fs.normalize(name)
  if state.files[path] or state.methods[path] then
    return path
  end
  -- the report holds the real path, the buffer may have been opened through a
  -- symlink
  local real = vim.uv.fs_realpath(name)
  if not real then
    return nil
  end
  real = vim.fs.normalize(real)
  return (state.files[real] or state.methods[real]) and real or nil
end

--- @param buf integer
--- @return table<integer, CoverageLine>?
local function lines_for(buf)
  local path = path_for(buf)
  return path and state.files[path] or nil
end

--- whether a buffer should be showing coverage, a buffer-local override beats
--- the global switch, so one file can be lit on its own, or muted while the
--- rest of the project stays lit
--- @param buf integer
--- @return boolean
local function shown(buf)
  local override = vim.b[buf].coverage_enabled
  if override ~= nil then
    return override
  end
  return state.active
end

--- @param buf integer
local function render(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not state.loaded or not shown(buf) then
    return
  end

  local path = path_for(buf)
  if not path then
    return
  end

  local last = vim.api.nvim_buf_line_count(buf)

  for lnum, rec in pairs(state.files[path] or {}) do
    if lnum >= 1 and lnum <= last then
      local kind = classify(rec)
      -- a partial line is the only one holding a number the gutter cannot say,
      -- how many of its paths were taken
      local virt = nil
      if M.config.branch_virt_text and kind == "partial" then
        virt = {
          {
            ("%d/%d branches"):format(rec.btaken, rec.btotal),
            hlgroups.partial,
          },
        }
      end
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
        sign_text = M.config.signs[kind],
        sign_hl_group = hlgroups[kind],
        line_hl_group = M.config.line_highlight and linegroups[kind] or nil,
        virt_text = virt,
        virt_text_pos = virt and "eol" or nil,
        priority = M.config.priority,
      })
    end
  end

  -- a method that was never entered outranks the plain uncovered sign on its
  -- own line, dead code reads differently from a body that was merely skipped
  if not M.config.method_signs then
    return
  end

  -- two methods can land on one signature line, an auto-property's getter and
  -- setter both do, so resolve every method first and let a live one win, a
  -- signature that anything reached is not dead
  local anchors = {}
  for lnum, visited in pairs(state.methods[path] or {}) do
    if lnum >= 1 and lnum <= last then
      local anchor = signature_line(buf, lnum)
      anchors[anchor] = (anchors[anchor] or false) or visited
    end
  end

  for lnum, visited in pairs(anchors) do
    if not visited then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
        sign_text = M.config.signs.method,
        sign_hl_group = method_hl,
        priority = M.config.priority + 1,
      })
    end
  end
end

--- drop every per-buffer override, so the project switch speaks for all of them
local function clear_overrides()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.b[buf].coverage_enabled = nil
    end
  end
end

local function render_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    render(buf)
  end
end

local function stop_watch()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  for _, handle in ipairs(state.handles) do
    handle:stop()
    if not handle:is_closing() then
      handle:close()
    end
  end
  state.handles = {}
end

--- watch every directory a report can appear in
local function start_watch()
  stop_watch()
  if not M.config.watch or #state.watch_dirs == 0 then
    return
  end

  local timer = vim.uv.new_timer()
  state.timer = timer

  for _, dir in ipairs(state.watch_dirs) do
    if vim.uv.fs_stat(dir) then
      local handle = vim.uv.new_fs_event()
      if handle then
        local ok = pcall(function()
          handle:start(dir, {}, function()
            -- a report is written in bursts, settle before re-reading it
            timer:stop()
            timer:start(
              300,
              0,
              vim.schedule_wrap(function()
                if state.loaded then
                  -- the current buffer is whatever the user happens to be in by
                  -- now, so reload against the root the report was found under
                  M.load({
                    notify = false,
                    activate = false,
                    root = state.root,
                  })
                end
              end)
            )
          end)
        end)
        if ok then
          state.handles[#state.handles + 1] = handle
        end
      end
    end
  end
end

--- @class CoverageMetric
--- @field covered integer
--- @field total integer

--- @class CoverageStats
--- @field lines CoverageMetric
--- @field branches CoverageMetric
--- @field methods CoverageMetric

--- line coverage counts a partially covered line as covered, it did run, which
--- is the same definition cobertura's line-rate and opencover's sequenceCoverage
--- use, so these numbers line up with the ones the html report prints
--- @param lines table<integer, CoverageLine>?
--- @param methods table<integer, boolean>?
--- @return CoverageStats
local function summarise(lines, methods)
  local stats = {
    lines = { covered = 0, total = 0 },
    branches = { covered = 0, total = 0 },
    methods = { covered = 0, total = 0 },
  }

  for _, rec in pairs(lines or {}) do
    stats.lines.total = stats.lines.total + 1
    if rec.hits > 0 then
      stats.lines.covered = stats.lines.covered + 1
    end
    stats.branches.total = stats.branches.total + rec.btotal
    stats.branches.covered = stats.branches.covered + rec.btaken
  end

  for _, visited in pairs(methods or {}) do
    stats.methods.total = stats.methods.total + 1
    if visited then
      stats.methods.covered = stats.methods.covered + 1
    end
  end

  return stats
end

--- a metric with nothing in it is left out rather than printed as 0%, a go
--- coverprofile has no branches and no methods and never will
--- @param stats CoverageStats
--- @return string
local function format_stats(stats)
  local parts = {}
  for _, metric in ipairs({
    { "lines", stats.lines },
    { "branches", stats.branches },
    { "methods", stats.methods },
  }) do
    local label, m = metric[1], metric[2]
    if m.total > 0 then
      parts[#parts + 1] = ("%s %.1f%% (%d/%d)"):format(
        label,
        m.covered / m.total * 100,
        m.covered,
        m.total
      )
    end
  end
  return table.concat(parts, ", ")
end

--- @param opts? { file?: string, notify?: boolean, activate?: boolean, root?: string }
function M.load(opts)
  opts = opts or {}
  -- exrc sources a project's .nvim.lua after init.lua has already run setup, so
  -- the project's settings are only guaranteed to be here by the time a report
  -- is actually asked for
  M.resolve()
  -- a reload carries the root over. The current buffer is no longer the one the
  -- report was found from, it can be the summary's scratch buffer or a file in
  -- another project entirely
  local root = opts.root or find_root(0)
  --- @type table<string, string[]> format to the report paths found for it
  local reports = {}

  if opts.file then
    local path = vim.fs.normalize(vim.fn.fnamemodify(opts.file, ":p"))
    -- an explicit file still has to be classified, go by shape not by name
    local content = read(path)
    if not content then
      return vim.notify("coverage: cannot read " .. path, vim.log.levels.ERROR)
    end
    local format = content:match("<CoverageSession") and "opencover"
      or content:match("<coverage") and "cobertura"
      or content:match("^mode:") and "go"
    if not format then
      return vim.notify(
        "coverage: unrecognised report format in " .. path,
        vim.log.levels.ERROR
      )
    end
    reports[format] = { path }
  else
    reports = discover(root)
  end

  --- @type CoverageReport
  local report = { files = {}, methods = {}, groups = {} }
  local loaded = {}
  local dirs = {}

  for format, paths in pairs(reports) do
    local contents = {}
    for _, path in ipairs(paths) do
      contents[path] = read(path)
    end
    if format == "cobertura" then
      paths = newest_per_project(paths, contents)
    end

    for _, path in ipairs(paths) do
      local content = contents[path]
      if content then
        merge(report, parsers[format](content, root))
        loaded[#loaded + 1] = path

        local dir = vim.fs.dirname(path)
        dirs[dir] = true
        -- opencover and go rewrite their report in place, so the file's own
        -- directory is enough. Cobertura appears in a whole new guid directory
        -- per run, so the directory the guids are created in has to be watched
        -- too
        if format == "cobertura" and is_guid_dir(dir) then
          local parent = vim.fs.dirname(dir)
          if within(parent, root) then
            dirs[parent] = true
          end
        end
      end
    end
  end

  if #loaded == 0 then
    if opts.notify ~= false then
      vim.notify(
        "coverage: no report found under " .. root,
        vim.log.levels.WARN
      )
    end
    return
  end

  state.root = root
  state.files = report.files
  state.methods = report.methods
  state.groups = report.groups
  state.reports = loaded
  state.watch_dirs = vim.tbl_keys(dirs)
  state.loaded = true

  -- a reload from the watcher passes activate = false, it must refresh the data
  -- without turning the project switch on behind the user's back, or wiping the
  -- per-buffer overrides they set
  if opts.activate ~= false then
    state.active = true
    clear_overrides()
  end

  render_all()
  start_watch()

  if opts.notify ~= false then
    vim.notify(
      ("coverage: %s, %d report%s"):format(
        format_stats(M.stats()),
        #loaded,
        #loaded == 1 and "" or "s"
      )
    )
  end
end

--- the loaded report, keyed by absolute path
--- @return CoverageFiles
function M.data()
  return state.files
end

--- the loaded methods, keyed by absolute path
--- @return CoverageMethods
function M.method_data()
  return state.methods
end

--- the assembly each file was compiled into, keyed by absolute path
--- @return CoverageGroups
function M.group_data()
  return state.groups
end

--- @return string? the project root the loaded report was found under
function M.root()
  return state.root
end

--- @return boolean
function M.is_loaded()
  return state.loaded
end

--- @return string[] every file the report says anything about
function M.paths()
  local seen = {}
  for path in pairs(state.files) do
    seen[path] = true
  end
  for path in pairs(state.methods) do
    seen[path] = true
  end
  return vim.tbl_keys(seen)
end

--- @param path string
--- @return CoverageStats
function M.file_stats(path)
  return summarise(state.files[path], state.methods[path])
end

--- @param path string
--- @return integer? the first line of the file no test reached
function M.first_uncovered(path)
  local first
  for lnum, rec in pairs(state.files[path] or {}) do
    if rec.hits == 0 and (not first or lnum < first) then
      first = lnum
    end
  end
  return first
end

--- light a buffer up without touching the project switch, so jumping out of the
--- summary window into a file shows what the summary was talking about
--- @param buf integer
function M.show_buffer(buf)
  if not shown(buf) then
    vim.b[buf].coverage_enabled = true
  end
  render(buf)
end

--- lines, branches and methods, for one buffer or for the whole project
--- @param buf integer? nil for the project
--- @return CoverageStats
function M.stats(buf)
  if buf then
    local path = path_for(buf)
    return summarise(
      path and state.files[path] or nil,
      path and state.methods[path] or nil
    )
  end

  local total = summarise(nil, nil)
  for path, lines in pairs(state.files) do
    local stats = summarise(lines, state.methods[path])
    for _, key in ipairs({ "lines", "branches", "methods" }) do
      total[key].covered = total[key].covered + stats[key].covered
      total[key].total = total[key].total + stats[key].total
    end
  end
  -- a file can hold methods without holding a single coverable line
  for path, methods in pairs(state.methods) do
    if not state.files[path] then
      local stats = summarise(nil, methods)
      total.methods.covered = total.methods.covered + stats.methods.covered
      total.methods.total = total.methods.total + stats.methods.total
    end
  end
  return total
end

function M.clear()
  state.active = false
  state.loaded = false
  state.root = nil
  state.files = {}
  state.methods = {}
  state.groups = {}
  state.reports = {}
  state.watch_dirs = {}
  stop_watch()
  clear_overrides()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
end

--- the project switch, every buffer open now and every buffer opened later
function M.toggle()
  if state.active then
    M.clear()
  else
    M.load()
  end
end

--- this buffer only, leaving the rest of the project as it was, the report is
--- read on demand so it works with the project switch off
function M.toggle_buffer()
  local buf = vim.api.nvim_get_current_buf()
  if not state.loaded then
    M.load({ activate = false, notify = false })
    if not state.loaded then
      return vim.notify("coverage: no report found", vim.log.levels.WARN)
    end
  end

  local on = not shown(buf)
  vim.b[buf].coverage_enabled = on
  render(buf)

  if not on then
    return
  end
  if not path_for(buf) then
    return vim.notify("coverage: no data for this file", vim.log.levels.WARN)
  end
  vim.notify(("coverage: %s"):format(format_stats(M.stats(buf))))
end

--- allow line highlighting to be toggled
function M.toggle_line_highlight()
  M.config.line_highlight = not M.config.line_highlight
  render_all()
end

--- the coverage of the current buffer, the number that actually matters while
--- writing a test
function M.summary()
  if not state.loaded then
    return vim.notify("coverage: not loaded", vim.log.levels.WARN)
  end
  local buf = vim.api.nvim_get_current_buf()
  if not path_for(buf) then
    return vim.notify("coverage: no data for this file", vim.log.levels.WARN)
  end
  vim.notify(("coverage: %s"):format(format_stats(M.stats(buf))))
end

--- @param backwards boolean?
function M.goto_uncovered(backwards)
  local buf = vim.api.nvim_get_current_buf()
  local lines = lines_for(buf)
  if not state.loaded or not lines then
    return vim.notify("coverage: no data for this file", vim.log.levels.WARN)
  end

  local uncovered = {}
  for lnum, rec in pairs(lines) do
    if rec.hits == 0 then
      uncovered[#uncovered + 1] = lnum
    end
  end
  table.sort(uncovered)
  if #uncovered == 0 then
    return vim.notify("coverage: this file is fully covered")
  end

  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if backwards then
    for i = #uncovered, 1, -1 do
      if uncovered[i] < cur then
        target = uncovered[i]
        break
      end
    end
    target = target or uncovered[#uncovered]
  else
    for _, lnum in ipairs(uncovered) do
      if lnum > cur then
        target = lnum
        break
      end
    end
    target = target or uncovered[1]
  end

  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zz")
end

--- mix a foreground color into a background one
--- @param fg integer
--- @param bg integer
--- @param alpha number
--- @return integer
local function mix(fg, bg, alpha)
  local function channel(color, shift)
    return math.floor(color / shift) % 256
  end
  local out = 0
  for _, shift in ipairs({ 65536, 256, 1 }) do
    local value = channel(fg, shift) * alpha + channel(bg, shift) * (1 - alpha)
    out = out + math.floor(math.min(255, math.max(0, value)) + 0.5) * shift
  end
  return out
end

local function set_hl()
  local hl = {
    [hlgroups.covered] = "DiagnosticOk",
    [hlgroups.uncovered] = "DiagnosticError",
    [hlgroups.partial] = "DiagnosticWarn",
    [method_hl] = "DiagnosticError",
  }
  for name, link in pairs(hl) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end

  -- a colorscheme can leave Normal without a background, a terminal showing
  -- through, so fall back to the extreme the background option implies
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local bg = normal.bg or (vim.o.background == "dark" and 0x000000 or 0xffffff)

  for kind, sign in pairs(hlgroups) do
    -- link = false resolves the link, so a colorscheme that restyles
    -- DiagnosticOk still drives the tint
    local fg = vim.api.nvim_get_hl(0, { name = sign, link = false }).fg
    if fg then
      vim.api.nvim_set_hl(0, linegroups[kind], {
        bg = mix(fg, bg, M.config.blend),
        default = true,
      })
    end
  end
end

function M.setup(opts)
  overrides = opts or {}
  M.resolve()

  -- cleared, not appended to, so calling setup twice replaces its autocmds
  -- instead of stacking them, exrc re-sources a project on every DirChanged
  local group = vim.api.nvim_create_augroup("coverage", { clear = true })

  set_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    desc = "Re-assert the coverage highlight links after a colorscheme change",
    group = group,
    callback = set_hl,
  })

  -- a buffer opened after the report was loaded still gets its gutters
  vim.api.nvim_create_autocmd("BufWinEnter", {
    desc = "Render coverage signs into a newly shown buffer",
    group = group,
    callback = function(ev)
      if state.active then
        render(ev.buf)
      end
    end,
  })

  -- a :cd into another repo sources its .nvim.lua, take up whatever it set
  vim.api.nvim_create_autocmd("DirChanged", {
    desc = "Re-resolve coverage settings against the project moved into",
    group = group,
    callback = function()
      M.resolve()
    end,
  })

  vim.api.nvim_create_user_command("CoverageToggle", function()
    M.toggle()
  end, { desc = "Toggle coverage gutters" })

  vim.api.nvim_create_user_command("CoverageLoad", function(cmd)
    M.load({ file = cmd.args ~= "" and cmd.args or nil })
  end, {
    desc = "Load a coverage report, discovered or given",
    nargs = "?",
    complete = "file",
  })

  vim.api.nvim_create_user_command("CoverageClear", function()
    M.clear()
  end, { desc = "Hide coverage gutters" })

  vim.api.nvim_create_user_command("CoverageBuffer", function()
    M.toggle_buffer()
  end, { desc = "Toggle coverage for the current buffer only" })

  vim.api.nvim_create_user_command("CoverageSummary", function()
    M.summary()
  end, { desc = "Coverage of the current buffer" })

  vim.api.nvim_create_user_command("CoverageHighlight", function()
    M.toggle_line_highlight()
  end, { desc = "Toggle the tinted line body, leaving the gutter alone" })

  vim.api.nvim_create_user_command("CoverageReport", function()
    require("util.coverage_summary").open()
  end, { desc = "The coverage summary window" })
end

return M
