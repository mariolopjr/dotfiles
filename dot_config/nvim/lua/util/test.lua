--- Test running on top of neotest, the adapters live in plugins/test.lua
--- neotest owns discovery and running, this only flattens what it found into
--- something a picker can show
local M = {}

--- A neotest position
--- @class util.test.Position
--- @field id string neotest position id
--- @field adapter string neotest adapter id
--- @field type string neotest position type
--- @field name string
--- @field scope string? the class or suite the position sits in
--- @field path string
--- @field lnum integer
--- @field count integer? tests underneath a file or namespace
--- @field suite boolean? run every test the adapter knows about

--- Adapter ids are "<name>:<root>", and the root is the solution or module dir
--- @param adapter string
--- @return string
local function adapter_root(adapter)
  return adapter:match("^[^:]+:(.*)$") or adapter
end

-- The nearest enclosing namespace, the class in C# and the suite in Go
--- @param node neotest.Tree
--- @return string?
local function scope_of(node)
  for parent in node:iter_parents() do
    local data = parent:data()
    if data.type == "namespace" then
      return data.name
    end
  end
end

--- @param node neotest.Tree
--- @return integer
local function count_tests(node)
  local total = 0
  for _, child in node:iter_nodes() do
    if child:data().type == "test" then
      total = total + 1
    end
  end
  return total
end

--- Flatten every position neotest has discovered across every adapter
--- @param wanted table<string, true> position types to keep
--- @return util.test.Position[]
local function collect(wanted)
  local neotest = require("neotest")
  local found = {}

  for _, adapter in ipairs(neotest.state.adapter_ids()) do
    local tree = neotest.state.positions(adapter)
    if tree then
      for _, node in tree:iter_nodes() do
        local pos = node:data()
        if wanted[pos.type] then
          found[#found + 1] = {
            id = pos.id,
            adapter = adapter,
            type = pos.type,
            name = pos.name,
            scope = scope_of(node),
            path = pos.path,
            lnum = (pos.range and pos.range[1] or 0) + 1,
            count = pos.type ~= "test" and count_tests(node) or nil,
          }
        end
      end
    end
  end

  table.sort(found, function(a, b)
    if a.path ~= b.path then
      return a.path < b.path
    end
    return a.lnum < b.lnum
  end)

  return found
end

--- Callbacks waiting on a discovery that is already running
--- @type fun()[]?
local waiting

-- spinner progress notification for test discovery
local NOTIFICATION = "neotest_discovery"

local spinner =
  { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- Everything neotest is currently holding
--- @return integer tests
--- @return integer files
local function tally()
  local neotest = require("neotest")
  local tests, files = 0, 0

  for _, adapter in ipairs(neotest.state.adapter_ids()) do
    local tree = neotest.state.positions(adapter)
    if tree then
      for _, node in tree:iter_nodes() do
        local kind = node:data().type
        if kind == "test" then
          tests = tests + 1
        elseif kind == "file" then
          files = files + 1
        end
      end
    end
  end

  return tests, files
end

--- @param message string
local function notify_begin(message)
  vim.notify(message, vim.log.levels.INFO, {
    id = NOTIFICATION,
    title = "neotest",
    -- discovery builds the solution
    timeout = false,
    -- a function here is re-run on every refresh
    opts = function(notif)
      notif.icon =
        spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
    end,
  })
end

local function notify_end()
  local tests, files = tally()

  local function plural(n, word)
    return ("%d %s%s"):format(n, word, n == 1 and "" or "s")
  end

  vim.notify(
    tests > 0
        and ("%s in %s"):format(plural(tests, "test"), plural(files, "file"))
      or "no tests found",
    tests > 0 and vim.log.levels.INFO or vim.log.levels.WARN,
    {
      id = NOTIFICATION,
      title = "neotest",
      icon = tests > 0 and " " or " ",
    }
  )
end

--- Neotest only discovers once a consumer asks its client for something, and
--- until then the state consumer reads back empty, so ask before reading it.
--- @param callback fun()
local function discovered(callback)
  local neotest = require("neotest")

  if #neotest.state.adapter_ids() > 0 then
    return callback()
  end

  -- the warm-up is usually already running, so join it instead of starting a
  -- second discovery on top of it
  if waiting then
    waiting[#waiting + 1] = callback
    return
  end
  waiting = { callback }

  notify_begin("discovering tests")

  require("nio").run(function()
    neotest.run.get_tree_from_args({ suite = true }, false)
  end, function()
    vim.schedule(function()
      notify_end()

      local queued = waiting or {}
      waiting = nil
      for _, queued_callback in ipairs(queued) do
        queued_callback()
      end
    end)
  end)
end

--- Discover in the background
function M.warm()
  discovered(function() end)
end

--- Open every directory and file in the summary.
function M.expand_summary()
  local neotest = require("neotest")

  discovered(function()
    for _, adapter in ipairs(neotest.state.adapter_ids()) do
      local tree = neotest.state.positions(adapter)
      if tree then
        neotest.summary:expand(tree:data().id, true)
      end
    end
  end)
end

--- Rescan the project for test files it has not seen.
---
--- Neotest has no file watcher and no refresh of its own. It only rediscovers a
--- directory when a buffer is added to it, so a test file written behind nvim's
--- back, by an agent or a git pull, stays invisible until something opens it.
--- Firing that same event against every adapter root rescans the tree, and
--- aiming it at neotest's own augroup keeps the synthetic event away from every
--- other plugin listening on BufAdd
function M.refresh()
  local neotest = require("neotest")

  -- nothing has been discovered yet, so the cold discovery is the refresh
  if #neotest.state.adapter_ids() == 0 then
    return M.warm()
  end

  notify_begin("rescanning tests")

  for _, adapter in ipairs(neotest.state.adapter_ids()) do
    -- neotest takes the parent of whatever is named here, so it names no file
    pcall(vim.api.nvim_exec_autocmds, "BufAdd", {
      group = "neotest.Client",
      pattern = vim.fs.joinpath(adapter_root(adapter), "neotest-refresh"),
    })
  end

  -- the rescan reports nothing back when it lands, so watch the count settle
  local timer = assert(vim.uv.new_timer())
  local last, stable, waited = -1, 0, 0

  timer:start(
    300,
    300,
    vim.schedule_wrap(function()
      local tests = tally()
      stable = tests == last and stable + 1 or 0
      last = tests
      waited = waited + 300

      if stable >= 3 or waited > 60000 then
        timer:stop()
        timer:close()
        notify_end()
      end
    end)
  )
end

--- @param pos util.test.Position
--- @param strategy string? "dap" to debug instead of run
local function run_position(pos, strategy)
  local neotest = require("neotest")

  if pos.suite then
    neotest.run.run({ suite = true, adapter = pos.adapter, strategy = strategy })
  else
    neotest.run.run({ pos.id, adapter = pos.adapter, strategy = strategy })
  end
end

--- Run every test in the project, which is every project in a solution and
--- every package in a Go module
--- @param strategy string?
function M.run_all(strategy)
  discovered(function()
    local neotest = require("neotest")
    local adapters = neotest.state.adapter_ids()

    if #adapters == 0 then
      vim.notify(
        "neotest: no adapter claimed this project",
        vim.log.levels.WARN
      )
      return
    end

    for _, adapter in ipairs(adapters) do
      neotest.run.run({ suite = true, adapter = adapter, strategy = strategy })
    end
  end)
end

--- @param picker snacks.Picker
--- @param strategy string?
local function run_chosen(picker, strategy)
  -- fallback picks up the line under the cursor when nothing is <Tab>-selected
  local chosen = picker:selected({ fallback = true })
  picker:close()

  for _, item in ipairs(chosen) do
    run_position(item.position, strategy)
  end
end

--- @param opts { title: string, items: snacks.picker.finder.Item[], format: snacks.picker.format, swap: fun() }
local function pick(opts)
  return Snacks.picker.pick({
    source = "neotest",
    title = opts.title,
    items = opts.items,
    format = opts.format,
    preview = "file",
    confirm = function(picker)
      run_chosen(picker)
    end,
    actions = {
      debug = function(picker)
        run_chosen(picker, "dap")
      end,
      run_all = function(picker)
        picker:close()
        M.run_all()
      end,
      swap = function(picker)
        picker:close()
        opts.swap()
      end,
      jump = function(picker, item)
        picker:close()
        if item then
          vim.cmd.edit(item.file)
          pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], 0 })
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-d>"] = { "debug", mode = { "i", "n" } },
          ["<c-a>"] = { "run_all", mode = { "i", "n" } },
          ["<c-s>"] = { "swap", mode = { "i", "n" } },
          ["<c-o>"] = { "jump", mode = { "i", "n" } },
        },
      },
    },
  })
end

local function warn_empty()
  vim.notify(
    "neotest: nothing discovered yet, open a test file first",
    vim.log.levels.WARN
  )
end

--- Every test in the project, <CR> runs and <C-d> debugs
function M.pick_tests()
  discovered(M._pick_tests)
end

--- @private
function M._pick_tests()
  local positions = collect({ test = true })

  if #positions == 0 then
    return warn_empty()
  end

  local items = {}
  for i, pos in ipairs(positions) do
    items[#items + 1] = {
      idx = i,
      score = 0,
      text = table.concat({
        pos.scope or "",
        pos.name,
        vim.fn.fnamemodify(pos.path, ":t"),
      }, " "),
      file = pos.path,
      pos = { pos.lnum, 0 },
      position = pos,
    }
  end

  pick({
    title = "Tests",
    items = items,
    swap = M.pick_scopes,
    format = function(item)
      local pos = item.position
      local out = {}

      if pos.scope then
        out[#out + 1] = { pos.scope .. ".", "SnacksPickerComment" }
      end
      out[#out + 1] = { pos.name, "SnacksPickerLabel" }
      out[#out + 1] = { " " }
      out[#out + 1] =
        { vim.fn.fnamemodify(pos.path, ":."), "SnacksPickerDimmed" }

      return out
    end,
  })
end

--- The scopes a run can cover, the whole suite or a single file, so that a
--- solution or a go module runs from the same picker the tests do
function M.pick_scopes()
  discovered(M._pick_scopes)
end

--- @private
function M._pick_scopes()
  local neotest = require("neotest")
  local positions = {}

  for _, adapter in ipairs(neotest.state.adapter_ids()) do
    local tree = neotest.state.positions(adapter)
    if tree then
      positions[#positions + 1] = {
        adapter = adapter,
        suite = true,
        type = "suite",
        name = vim.fn.fnamemodify(adapter_root(adapter), ":t"),
        path = adapter_root(adapter),
        lnum = 1,
        count = count_tests(tree),
      }
    end
  end

  vim.list_extend(positions, collect({ file = true }))

  if #positions == 0 then
    return warn_empty()
  end

  local items = {}
  for i, pos in ipairs(positions) do
    items[#items + 1] = {
      idx = i,
      score = 0,
      text = pos.name .. " " .. vim.fn.fnamemodify(pos.path, ":."),
      file = pos.path,
      pos = { pos.lnum, 0 },
      position = pos,
    }
  end

  pick({
    title = "Test Scopes",
    items = items,
    swap = M.pick_tests,
    format = function(item)
      local pos = item.position
      local out = {}

      if pos.suite then
        out[#out + 1] = { "everything in ", "SnacksPickerComment" }
        out[#out + 1] = { pos.name, "SnacksPickerLabel" }
      else
        out[#out + 1] =
          { vim.fn.fnamemodify(pos.path, ":."), "SnacksPickerLabel" }
      end

      out[#out + 1] = { " " }
      out[#out + 1] =
        { ("(%d tests)"):format(pos.count or 0), "SnacksPickerDimmed" }

      return out
    end,
  })
end

return M
