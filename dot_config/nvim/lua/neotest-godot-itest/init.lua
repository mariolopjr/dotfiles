-- Neotest adapter for the godot-rust template's in-engine itest harness.
-- Discovers `itest! { fn name(ctx) { ... } }` macros in rust files, runs them
-- with `just test-godot [filter]`, and parses the runner's stable output:
--   ok lines    "  ok   <name>"
--   fail lines  "ERROR:   FAIL <name> (<file>:<line>): <message>"

local lib = require("neotest.lib")

local adapter = { name = "godot-itest" }

---@param dir string
---@return string?
adapter.root = function(dir)
  ---@type string?
  local current = dir
  while current do
    if vim.uv.fs_stat(current .. "/godot/itest.tscn") then
      return current
    end
    local parent = vim.fs.dirname(current)
    current = parent ~= current and parent or nil
  end
  return nil
end

---@param name string
---@param rel_path string
---@return boolean
adapter.filter_dir = function(name, rel_path)
  local _ = name
  return vim.startswith(rel_path, "crates")
end

---@param file_path string
---@return boolean
adapter.is_test_file = function(file_path)
  if not vim.endswith(file_path, ".rs") then
    return false
  end
  -- plain io, lib.files.read silently truncates outside an async context
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
  -- debugging an itest means attaching to godot, that lives in the template's
  -- .nvim.lua dap configs, not here
  if args.strategy == "dap" then
    return nil
  end

  local pos = args.tree:data()
  local root = adapter.root(pos.path)
  if not root then
    return nil
  end

  local command = { "just", "test-godot" }
  if pos.type == "test" then
    table.insert(command, pos.name)
  end
  -- a file or dir run gets no filter: the harness runs the whole crate, the
  -- results parser scopes what lands in the tree

  return { command = command, cwd = root }
end

---@param spec table
---@param result table
---@param tree table
---@return table
adapter.results = function(spec, result, tree)
  local _ = spec
  local passed = {}
  local failed = {}

  local out_file = io.open(result.output, "r")
  if out_file then
    local output = out_file:read("*a")
    out_file:close()
    for line in output:gmatch("[^\r\n]+") do
      local name = line:match("^%s+ok%s+([%w_]+)%s*$")
      if name then
        passed[name] = true
      end
      local fail_name, file, lnum, message =
        line:match("FAIL%s+([%w_]+)%s+%(([^:]+):(%d+)%):%s*(.*)")
      if fail_name then
        failed[fail_name] =
          { file = file, line = tonumber(lnum), message = message }
      end
    end
  end

  local results = {}
  for _, position in tree:iter() do
    if position.type == "test" then
      if passed[position.name] then
        results[position.id] = { status = "passed" }
      elseif failed[position.name] then
        local fail = failed[position.name]
        local err = { message = fail.message }
        -- only anchor the diagnostic when the failure is in this file
        if fail.file and vim.endswith(position.path, fail.file) then
          err.line = fail.line - 1
        end
        results[position.id] = {
          status = "failed",
          short = position.name .. ": " .. fail.message,
          errors = { err },
        }
      else
        -- not in the output: filtered out, or the runner quit before it ran
        results[position.id] = { status = "skipped" }
      end
    end
  end
  return results
end

return adapter
