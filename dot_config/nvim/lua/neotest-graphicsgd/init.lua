-- Neotest adapter for graphics.gd test suites

local lib = require("neotest.lib")

local adapter = { name = "graphicsgd" }

---@param dir string
---@return string?
adapter.root = function(dir)
  return require("util.go").graphics_root(dir)
end

---@param name string
---@param rel_path string
---@return boolean
adapter.filter_dir = function(name, rel_path)
  if name == "vendor" then
    return false
  end
  -- graphics/ is the godot project and releases/ is gd build's output dir
  if rel_path == name then
    return name ~= "graphics" and name ~= "releases"
  end
  return true
end

---@param file_path string
---@return boolean
adapter.is_test_file = function(file_path)
  return vim.endswith(file_path, "_test.go")
end

---@param file_path string
adapter.discover_positions = function(file_path)
  local query = [[
    (function_declaration
      name: (identifier) @test.name (#match? @test.name "^Test")
      parameters: (parameter_list
        (parameter_declaration
          type: (pointer_type (qualified_type
            package: (package_identifier) @_pkg (#eq? @_pkg "testing")
            name: (type_identifier) @_typ (#eq? @_typ "T")))))
    ) @test.definition
  ]]
  return lib.treesitter.parse_positions(
    file_path,
    query,
    { nested_tests = false }
  )
end

--- A `-run` over every test
---@param tree table
---@return string?
local function run_filter(tree)
  local names = {}
  for _, node in tree:iter() do
    if node.type == "test" then
      names[#names + 1] = node.name
    end
  end
  if #names == 0 then
    return nil
  end
  return "^(" .. table.concat(names, "|") .. ")$"
end

--- The package argument for `gd test`
---@param root string
---@param dir string
---@param recurse boolean
---@return string
local function package_arg(root, dir, recurse)
  local rel = vim.fs.relpath(root, dir)
  local base = (rel == nil or rel == ".") and "." or "./" .. rel
  if not recurse then
    return base
  end
  return base == "." and "./..." or base .. "/..."
end

---@param args table
---@return table?
adapter.build_spec = function(args)
  local pos = args.tree:data()

  if args.strategy == "dap" then
    vim.schedule(function()
      vim.notify(
        "graphics.gd tests run inside godot, attach dap to the engine instead",
        vim.log.levels.WARN
      )
    end)
    return nil
  end

  local root = adapter.root(pos.path)
  if not root then
    return nil
  end

  local gd = require("util.go").gd()
  if not gd then
    return nil
  end

  local command = { gd, "test", "-v" }
  if pos.type == "test" then
    table.insert(command, "-run")
    table.insert(command, "^" .. pos.name .. "$")
  elseif pos.type == "file" then
    local filter = run_filter(args.tree)
    if filter then
      table.insert(command, "-run")
      table.insert(command, filter)
    end
  end

  local dir = pos.type == "dir" and pos.path or vim.fs.dirname(pos.path)
  table.insert(command, package_arg(root, dir, pos.type == "dir"))

  return { command = command, cwd = root }
end

--- The earliest failing subtest that contains a message
---@param seen table
---@param name string
---@return table?
local function subtest_failure(seen, name)
  local prefix = name .. "/"
  local found
  for key, entry in pairs(seen) do
    if
      entry.status == "failed"
      and entry.message
      and vim.startswith(key, prefix)
      and (not found or entry.order < found.order)
    then
      found = entry
    end
  end
  return found
end

---@param spec table
---@param result table
---@param tree table
---@return table
adapter.results = function(spec, result, tree)
  local _ = spec
  local output = ""
  local fd = io.open(result.output, "r")
  if fd then
    output = fd:read("*a")
    fd:close()
  end
  local seen = require("neotest-graphicsgd.parse").parse(output)

  local broken = next(seen) == nil and result.code ~= 0

  local results = {}
  for _, position in tree:iter() do
    if position.type == "test" then
      local entry = seen[position.name]
      if broken then
        results[position.id] = {
          status = "failed",
          short = "run failed before any test reported",
        }
      elseif not entry then
        -- filtered out by -run
        results[position.id] = { status = "skipped" }
      elseif entry.status == "failed" then
        local fail = entry.message and entry
          or subtest_failure(seen, position.name)
          or entry
        local message = fail.message or "failed"
        local err = { message = message }
        -- go reports the basename only
        if fail.line and fail.file == vim.fs.basename(position.path) then
          err.line = fail.line - 1
        end
        results[position.id] = {
          status = "failed",
          short = position.name .. ": " .. message,
          errors = { err },
        }
      else
        results[position.id] = { status = entry.status }
      end
    end
  end
  return results
end

return adapter
