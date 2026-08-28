-- Neotest adapter for the godot-rust template's in-engine itest harness

local lib = require("neotest.lib")

local adapter = { name = "godot-itest" }

---@param dir string
---@return string?
adapter.root = function(dir)
  return require("util.rust").itest_root(dir)
end

---@param name string
---@param rel_path string
---@return boolean
adapter.filter_dir = function(name, rel_path)
  if name == "target" then
    return false
  end
  -- godot/ is the engine project and build/ is the export output dir
  if rel_path == name then
    return name ~= "godot" and name ~= "build"
  end
  return true
end

---@param file_path string
---@return boolean
adapter.is_test_file = function(file_path)
  if not vim.endswith(file_path, ".rs") then
    return false
  end
  local file = io.open(file_path, "r")
  if not file then
    return false
  end
  local content = file:read("*a")
  file:close()
  return content:find("itest!", 1, true) ~= nil
end

---@param file_path string
adapter.discover_positions = function(file_path)
  -- inside a macro token_tree keywords stay anonymous tokens, so the only
  -- direct identifier child is the test name
  local query = [[
    (macro_invocation
      macro: (identifier) @_macro (#eq? @_macro "itest")
      (token_tree (identifier) @test.name)
    ) @test.definition
  ]]
  return lib.treesitter.parse_positions(
    file_path,
    query,
    { nested_tests = false }
  )
end

---@param args table
---@return table?
adapter.build_spec = function(args)
  local pos = args.tree:data()

  if args.strategy == "dap" then
    vim.schedule(function()
      vim.notify(
        "itests run inside godot, attach dap to the engine instead",
        vim.log.levels.WARN
      )
    end)
    return nil
  end

  local root = adapter.root(pos.path)
  if not root then
    return nil
  end

  local just = vim.fn.exepath("just")
  if just == "" then
    vim.schedule(function()
      vim.notify(
        "godot-itest: just is not on PATH, `just test-godot` runs the harness",
        vim.log.levels.ERROR
      )
    end)
    return nil
  end

  local command = { just, "test-godot" }
  if pos.type == "test" then
    table.insert(command, pos.name)
  end

  return { command = command, cwd = root }
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
  local seen = require("neotest-godot-itest.parse").parse(output)

  -- the crate failed to build or godot never reached the runner
  local broken = next(seen) == nil and result.code ~= 0

  local results = {}
  for _, position in tree:iter() do
    if position.type == "test" then
      local entry = seen[position.name]
      if broken then
        results[position.id] = {
          status = "failed",
          short = "the harness failed before any test reported",
        }
      elseif not entry then
        -- filtered out or the runner quit before it ran
        results[position.id] = { status = "skipped" }
      elseif entry.status == "failed" then
        local message = entry.message or "failed"
        local err = { message = message }
        -- only anchor the diagnostic when the failure is in this file
        if
          entry.line
          and entry.file
          and vim.endswith(position.path, entry.file)
        then
          err.line = entry.line - 1
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
