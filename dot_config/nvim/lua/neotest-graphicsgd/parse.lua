--- Reading `-test.v` output into per-test results

local M = {}

--- @param output string
--- @return table<string, { status: string, message: string?, file: string?, line: integer?, order: integer }>
function M.parse(output)
  local seen = {}
  local order = 0
  --- the test a `file.go:12: message` line originated from
  local current

  --- @param name string
  --- @return table
  local function entry_for(name)
    local entry = seen[name]
    if not entry then
      order = order + 1
      entry = { status = "skipped", order = order }
      seen[name] = entry
    end
    return entry
  end

  for line in (output or ""):gmatch("[^\r\n]+") do
    local kind, target = line:match("^===%s+(%u+)%s+(%S+)")
    -- the subtest result is indented under its parent
    local status, name = line:match("^%s*%-%-%-%s+(%u+):%s+(%S+)")
    if kind == "RUN" or kind == "CONT" or kind == "NAME" then
      -- CONT and NAME resume a test that paused for t.Parallel
      entry_for(target)
      current = target
    elseif status then
      local entry = entry_for(name)
      entry.status = status == "PASS" and "passed"
        or status == "SKIP" and "skipped"
        or "failed"
      current = name
    elseif current then
      -- t.Errorf writes `    file_test.go:12: message`
      local file, lnum, msg = line:match("^%s+([%w_%-%.]+%.go):(%d+):%s*(.*)$")
      if file then
        local entry = seen[current]
        -- the first message is the failure
        if entry and not entry.message then
          entry.file, entry.line, entry.message = file, tonumber(lnum), msg
        end
      end
    end
  end
  return seen
end

return M
