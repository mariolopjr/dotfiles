--- A neotest adapter for Chickensoft.GoDotTest
---
--- GoDotTest finds its tests by reflecting over the assembly of the running Godot
--- engine, so VSTest cannot enumerate them and neotest-vstest cannot run them.
--- This runs the Godot engine instead, `godot --run-tests=<glob> --quit-on-finish`,
--- and reads the log GoDotTest prints
---
--- The constraint that shapes everything here: `--run-tests=<glob>` matches suite
--- names, so the smallest thing GoDotTest can be asked to run is a whole class.
--- Running one test therefore runs the class it sits in. Results still come back
--- per test, so the summary stays per test
local lib = require("neotest.lib")
local parse = require("neotest-godottest.parse")

--- neotest.Adapter, plus the position id builder parse_positions resolves by name
--- @class godottest.Adapter : neotest.Adapter
--- @field _position_id? fun(position: neotest.Position, parents: neotest.Position[]): string

--- @type godottest.Adapter
local adapter = { name = "neotest-godottest" }

--- @param message string
--- @param level integer?
local function notify(message, level)
  vim.schedule(function()
    vim.notify(message, level or vim.log.levels.INFO, { title = "GoDotTest" })
  end)
end

--- @param path string
--- @return string
local function directory(path)
  local stat = vim.uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return path
  end
  return vim.fs.dirname(path)
end

local project = lib.files.match_root_pattern("project.godot")

--- Only load a Godot project that contains a godot test tree
---
--- Both adapters do end up rooted at this repo, since it holds a .sln and a
--- project.godot, but they never report the same test twice: is_test_file here
--- only ever says yes under test/, and the MSTest projects live under libs/
--- @param dir string
--- @return string?
function adapter.root(dir)
  local root = project(dir)
  if not root then
    return nil
  end

  local tests = vim.uv.fs_stat(vim.fs.joinpath(root, "test"))
  if not tests or tests.type ~= "directory" then
    return nil
  end

  return root
end

--- Only walk the godot test tree. libs/ holds MSTest projects that belong to
--- neotest-vstest, and src/ and addons/ hold no tests at all
--- @param name string
--- @param rel_path string
--- @param _ string the root, which the tree is already relative to
--- @return boolean
function adapter.filter_dir(name, rel_path, _)
  if name == "bin" or name == "obj" then
    return false
  end
  return rel_path == "test" or vim.startswith(rel_path, "test/")
end

--- @param file_path string
--- @return boolean
function adapter.is_test_file(file_path)
  if not vim.endswith(file_path, ".cs") then
    return false
  end

  local root = adapter.root(vim.fs.dirname(file_path))
  if not root then
    return false
  end

  if not vim.startswith(file_path, vim.fs.joinpath(root, "test") .. "/") then
    return false
  end

  -- a fixture or a helper living under test/ is not a suite, and an empty file in
  -- the summary is worse than not listing it
  local ok, content = pcall(lib.files.read, file_path)
  return ok and content:find("TestClass", 1, true) ~= nil
end

--- Suites are the classes deriving from TestClass, and tests are the methods
--- carrying [Test]. The lifecycle hooks ([Setup], [SetupAll], [Cleanup],
--- [CleanupAll], [Failure]) run around the tests but are not tests, and must not
--- become positions
---
--- The C# namespace is deliberately not a position. Every file has exactly one,
--- and GoDotTest matches on the bare class name, so a namespace level would only
--- add depth to the tree that nothing could address
local query = [[
  ;; class AppTest(Node testScene) : TestClass(testScene)
  (class_declaration
    name: (identifier) @namespace.name
    (base_list (identifier) @base (#eq? @base "TestClass"))
  ) @namespace.definition

  ;; [Test] public void Foo()
  (method_declaration
    (attribute_list
      (attribute
        (identifier) @attribute (#any-of? @attribute "Test" "TestAttribute")))
    name: (identifier) @test.name
  ) @test.definition
]]

--- `<file>::<Suite>::<Method>`, because `<Suite>::<Method>` is exactly what
--- GoDotTest prints, so a line of output maps straight back onto a position
---
--- Passed to parse_positions by name rather than by value: neotest parses in a
--- subprocess when it can, and a function cannot cross that boundary
--- @param position neotest.Position
--- @param parents neotest.Position[]
--- @return string
function adapter._position_id(position, parents)
  local parts = { position.path }

  for _, parent in ipairs(parents) do
    if parent.type == "namespace" then
      parts[#parts + 1] = parent.name
    end
  end

  if position.type == "namespace" or position.type == "test" then
    parts[#parts + 1] = position.name
  end

  return table.concat(parts, "::")
end

--- @param file_path string
--- @return neotest.Tree?
function adapter.discover_positions(file_path)
  return lib.treesitter.parse_positions(file_path, query, {
    nested_tests = false,
    require_namespaces = false,
    -- neotest types position_id as a function, but only a string survives the
    -- subprocess, and that is the form it loadstrings back
    --- @diagnostic disable-next-line: assign-type-mismatch
    position_id = 'require("neotest-godottest")._position_id',
  })
end

--- The suite a test sits in
--- @param tree neotest.Tree
--- @return neotest.Tree?
local function suite_of(tree)
  for parent in tree:iter_parents() do
    if parent:data().type == "namespace" then
      return parent
    end
  end
  return nil
end

--- @param tree neotest.Tree
--- @return integer
local function count_tests(tree)
  local total = 0
  for _, node in tree:iter_nodes() do
    if node:data().type == "test" then
      total = total + 1
    end
  end
  return total
end

--- Every suite a position covers
--- @param tree neotest.Tree
--- @return string[]
local function suites_of(tree)
  local position = tree:data()

  if position.type == "test" then
    local suite = suite_of(tree)
    return suite and { suite:data().name } or {}
  end

  if position.type == "namespace" then
    return { position.name }
  end

  local names, seen = {}, {}
  for _, node in tree:iter_nodes() do
    local data = node:data()
    if data.type == "namespace" and not seen[data.name] then
      seen[data.name] = true
      names[#names + 1] = data.name
    end
  end
  return names
end

--- Godot is resolved through mise
--- @type table<string, string|false>
local godot_cache = {}

--- @param root string
--- @return string?
local function godot_bin(root)
  if vim.env.GODOT and vim.env.GODOT ~= "" then
    return vim.env.GODOT
  end

  local cached = godot_cache[root]
  if cached ~= nil then
    return cached or nil
  end

  --- @type string|false
  local resolved = false

  -- spawning goes through execvp should have mise on PATH.
  -- It throws when there is no mise to spawn
  local ok, code, out = pcall(
    lib.process.run,
    { "mise", "env", "-J", "-C", root },
    { stdout = true, stderr = false }
  )

  if ok and code == 0 and out.stdout then
    local decoded, env = pcall(vim.json.decode, out.stdout)
    if decoded and type(env) == "table" and env.GODOT and env.GODOT ~= "" then
      resolved = env.GODOT
    end
  end

  godot_cache[root] = resolved
  return resolved or nil
end

--- A path to write the build log to
--- @return string
local function temp_log()
  local name = ("neotest-godottest-%d-%d.log"):format(
    vim.uv.os_getpid(),
    vim.uv.hrtime()
  )
  return vim.fs.joinpath(vim.uv.os_tmpdir() or "/tmp", name)
end

--- @param args neotest.RunArgs
--- @return neotest.RunSpec?
function adapter.build_spec(args)
  local tree = args.tree
  if not tree then
    return nil
  end

  local position = tree:data()
  local root = adapter.root(directory(position.path))
  if not root then
    return nil
  end

  local godot = godot_bin(root)
  if not godot then
    notify(
      "GODOT is not set, so there is no engine to run the tests with. mise exports it, so open the project through mise",
      vim.log.levels.ERROR
    )
    return nil
  end

  local names = suites_of(tree)

  -- GoDotTest takes one glob, matched against suite names, so several suites
  -- cannot be named at once. A single Godot boot running everything beats one
  -- boot per suite, so anything covering more than one suite runs the lot, and
  -- the results that came back for free are reported rather than dropped
  local glob = #names == 1 and names[1] or nil

  if position.type == "test" then
    local suite = suite_of(tree)
    if suite and count_tests(suite) > 1 then
      notify(
        ("no single test can be run, so the whole %s suite runs"):format(
          suite:data().name
        )
      )
    end
  end

  -- the tests compile into the game assembly only in a Debug build
  local code, out = lib.process.run(
    { "dotnet", "build", root },
    { stdout = true, stderr = true }
  )

  if code ~= 0 then
    -- keep the compiler's own words, so the output panel explains the red tree
    local log = temp_log()
    lib.files.write(log, (out.stdout or "") .. (out.stderr or ""))
    return {
      command = { "false" },
      cwd = root,
      context = { root = root, build_log = log },
    }
  end

  local run = { "--audio-driver", "Dummy" }
  -- tests use a real scene and cannot be run headless
  run[#run + 1] = glob and ("--run-tests=" .. glob) or "--run-tests"
  run[#run + 1] = "--quit-on-finish"
  vim.list_extend(run, args.extra_args or {})

  --- @type neotest.RunSpec
  local spec = {
    command = vim.list_extend({ godot }, run),
    cwd = root,
    context = { root = root, glob = glob },
  }

  if args.strategy == "dap" then
    spec.strategy = {
      type = "coreclr",
      name = glob and ("GoDotTest: " .. glob) or "GoDotTest: every suite",
      request = "launch",
      program = godot,
      cwd = root,
      args = run,
    }
  end

  return spec
end

--- @param method godottest.Method
--- @param position neotest.Position
--- @param output string
--- @param broken godottest.Method? a hook in this test's suite that threw
--- @return neotest.Result
local function to_result(method, position, output, broken)
  -- the suite's setup blew up and took this test with it. GoDotTest calls that
  -- skipped, but skipped reads green enough to hide a suite that never ran
  if broken and method.status ~= "passed" and method.status ~= "failed" then
    local message = ("%s [%s] failed, so this test never ran: %s"):format(
      broken.method,
      broken.type,
      parse.message(broken)
    )
    return {
      status = "failed",
      output = output,
      short = message,
      errors = { { message = message } },
    }
  end

  if method.status == "passed" then
    return { status = "passed", output = output }
  end

  if method.status == "skipped" then
    return { status = "skipped", output = output }
  end

  if method.status == "failed" then
    local message = parse.message(method)
    return {
      status = "failed",
      output = output,
      short = message,
      errors = {
        { message = message, line = parse.line(method, position.path) },
      },
    }
  end

  -- it started and never reported, so the engine died part way through the suite
  local message = "the run ended before this test reported a result"
  return {
    status = "failed",
    output = output,
    short = message,
    errors = { { message = message } },
  }
end

--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function adapter.results(spec, result, tree)
  local context = spec.context or {}
  --- @type table<string, neotest.Result>
  local results = {}

  if context.build_log then
    -- nothing ran
    local message = "dotnet build failed, no tests ran"
    for _, node in tree:iter_nodes() do
      local data = node:data()
      if data.type == "test" then
        results[data.id] = {
          status = "failed",
          output = context.build_log,
          short = message,
          errors = { { message = message } },
        }
      end
    end
    notify(message, vim.log.levels.ERROR)
    return results
  end

  local ok, lines = pcall(lib.files.read_lines, result.output)
  local parsed = parse.parse(ok and lines or {})

  -- every test discovered, keyed the way GoDotTest names it. Running one test
  -- runs its whole suite
  --- @type table<string, neotest.Position[]>
  local positions = {}
  for _, node in tree:root():iter_nodes() do
    local data = node:data()
    if data.type == "test" then
      local suite = suite_of(node)
      if suite then
        local key = suite:data().name .. "::" .. data.name
        positions[key] = positions[key] or {}
        table.insert(positions[key], data)
      end
    end
  end

  -- a hook that throws takes its suite down with it, and GoDotTest blames the
  -- hook rather than the tests, so the tests have to be told
  --- @type table<string, godottest.Method>
  local broken = {}
  for _, method in pairs(parsed.methods) do
    if method.type ~= "Test" and method.status == "failed" then
      broken[method.suite] = broken[method.suite] or method
    end
  end

  for key, method in pairs(parsed.methods) do
    if method.type == "Test" then
      for _, position in ipairs(positions[key] or {}) do
        results[position.id] =
          to_result(method, position, result.output, broken[method.suite])
      end
    end
  end

  -- Check against GoDotTest's output and its exit code
  local warnings = {}
  local tally = parsed.tally

  if not tally then
    local message = ("GoDotTest printed no result tally (exit %d), so the run never finished"):format(
      result.code
    )
    table.insert(warnings, message)

    -- neotest reds whatever ran and reported nothing
    for _, node in tree:iter_nodes() do
      local data = node:data()
      if data.type == "test" and not results[data.id] then
        results[data.id] = {
          status = "failed",
          output = result.output,
          short = message,
          errors = { { message = message } },
        }
      end
    end
  else
    local counts = parsed.counts

    if
      counts.passed ~= tally.passed
      or counts.failed ~= tally.failed
      or counts.skipped ~= tally.skipped
    then
      table.insert(
        warnings,
        ("read %d passed %d failed %d skipped, but GoDotTest counted %d/%d/%d, so its output was not fully understood"):format(
          counts.passed,
          counts.failed,
          counts.skipped,
          tally.passed,
          tally.failed,
          tally.skipped
        )
      )
    end

    -- a glob matching no suite is a silent success
    if tally.passed + tally.failed + tally.skipped == 0 then
      table.insert(
        warnings,
        context.glob and ("no suite matched %q"):format(context.glob)
          or "GoDotTest found no tests to run"
      )
    end

    if result.code ~= 0 and tally.failed == 0 then
      table.insert(
        warnings,
        ("the run exited %d but GoDotTest reported no failures"):format(
          result.code
        )
      )
    end
  end

  -- a cleanup that throws after its tests pass leaves a failing run and a green
  -- tree
  for _, method in pairs(broken) do
    table.insert(
      warnings,
      ("%s::%s [%s] failed: %s"):format(
        method.suite,
        method.method,
        method.type,
        parse.message(method)
      )
    )
  end

  if #warnings > 0 then
    notify(table.concat(warnings, "\n"), vim.log.levels.WARN)
  end

  return results
end

return adapter
