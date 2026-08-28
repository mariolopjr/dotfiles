--- Reading the ITestRunner's output into per-test results
---
--- The runner prints one stable line per test and godot prefixes output through push_error with
--- ERROR
---   pass  "  ok   <name>"
---   fail  "ERROR:   FAIL <name> (<file>:<line>): <message>"

local M = {}

--- @param output string
--- @return table<string, { status: string, message: string?, file: string?, line: integer? }>
function M.parse(output)
  local seen = {}

  for line in (output or ""):gmatch("[^\r\n]+") do
    local passed = line:match("^%s+ok%s+([%w_]+)%s*$")
    if passed then
      seen[passed] = { status = "passed" }
    end

    local name, file, lnum, message =
      line:match("FAIL%s+([%w_]+)%s+%(([^:]+):(%d+)%):%s*(.*)")
    if name then
      seen[name] = {
        status = "failed",
        file = file,
        line = tonumber(lnum),
        message = message,
      }
    end
  end

  return seen
end

return M
