--- Parse the log Chickensoft.GoDotTest prints
---
--- GoDotTest results are written to stdout and parsed, along with Godot's
--- errors and the game logs. Any line without the `Info (GoTest):` prefix
--- will be ignored.
---
--- Examples from GoDotTest's TestReporter:
---
---   Info (GoTest): > OK >> AppTest::BootShowsMenu [Test] > Test passed! :)
---   Info (GoTest): > !! >> AppTest::BootShowsMenu [Test] > Test failed! :(
---   Info (GoTest): > ^^ >> AppTest::BootShowsMenu [Test] > Test skipped! :|
---   Info (GoTest): > ^^ >> AppTest::BootShowsMenu [Test] > Test started! :3
---   Info (GoTest): > !! >> AppTest::BootShowsMenu [Test] > Error occurred: <message>
---   Info (GoTest): > OK >> Test results: Passed: 3 | Failed: 0 | Skipped: 0
---
--- Started and passed are only ever printed for a [Test]. Failed and skipped are
--- printed for the lifecycle hooks too, so a [SetupAll] that throws shows up as
--- `AppTest::Setup [SetupAll] > Test failed!`, and GoDotTest counts it in its own
--- tally
local M = {}

--- a method event
local METHOD =
  "^Info %(GoTest%): > %S+ >> ([%w_]+)::([%w_]+) %[(%w+)%] > Test (%a+)!"

--- the failure detail
local FAILURE =
  "^Info %(GoTest%): > %S+ >> ([%w_]+)::([%w_]+) %[(%w+)%] > Error occurred: (.*)"

--- GoDotTest's own count
local TALLY =
  "^Info %(GoTest%): > %S+ >> Test results: Passed: (%d+) | Failed: (%d+) | Skipped: (%d+)"

local FINISHED = "^Info %(GoTest%): > %S+ >> Finished testing!"

local GOTEST = "^Info %(GoTest%): "

--- GoDotTest prints the exception itself through a trace listener
--- so the stack trace does not carry the `Info (GoTest):` prefix
---   Error: 0 : Error (GoTest): System.TimeoutException: Menu never appeared
local DETAIL = "^%s*Error: %d+ : Error %(GoTest%):%s?(.*)"

--- a stack frame that knows where it came from
---   at GodotGameTmpl.AppTest.WaitForContent[T]() in /path/AppTest.cs:line 67
local FRAME = "^%s*at .+ in (.+):line (%d+)%s*$"

--- @class godottest.Method
--- @field suite string the class
--- @field method string
--- @field type string the attribute carried, "Test" for a real test
--- @field status string? "started"|"passed"|"failed"|"skipped"
--- @field message string? the exception message
--- @field exception string? the exception with its type, preferred over message
--- @field frames { file: string, line: number }[] stack frames, innermost first

--- @class godottest.Output
--- @field methods table<string, godottest.Method> keyed by "<Suite>::<Method>"
--- @field suites table<string, true> every suite that reported anything
--- @field tally { passed: number, failed: number, skipped: number }? GoDotTest's count
--- @field counts { passed: number, failed: number, skipped: number } the parsed count
--- @field finished boolean whether the run reached the end

--- @param text string
--- @return number
local function num(text)
  return tonumber(text) or 0
end

--- @param lines string[]
--- @return godottest.Output
function M.parse(lines)
  --- @type godottest.Output
  local parsed = {
    methods = {},
    suites = {},
    counts = { passed = 0, failed = 0, skipped = 0 },
    finished = false,
  }

  --- the method whose exception block is being read cleared by the next GoTest line
  --- @type godottest.Method?
  local collecting

  --- @return godottest.Method
  local function entry(suite, method, method_type)
    local key = suite .. "::" .. method
    local found = parsed.methods[key]
    if not found then
      found =
        { suite = suite, method = method, type = method_type, frames = {} }
      parsed.methods[key] = found
      parsed.suites[suite] = true
    end
    return found
  end

  for _, line in ipairs(lines) do
    if line:match(GOTEST) then
      local suite, method, method_type, verb = line:match(METHOD)
      local failed_suite, failed_method, failed_type, message =
        line:match(FAILURE)
      local passed, failed, skipped = line:match(TALLY)

      if suite then
        local found = entry(suite, method, method_type)
        found.status = verb
        -- started is an event so don't count it
        if parsed.counts[verb] then
          parsed.counts[verb] = parsed.counts[verb] + 1
        end
      elseif failed_suite then
        -- the failure was already counted when the method reported
        collecting = entry(failed_suite, failed_method, failed_type)
        collecting.message = message
      elseif passed then
        parsed.tally = {
          passed = num(passed),
          failed = num(failed),
          skipped = num(skipped),
        }
      elseif line:match(FINISHED) then
        parsed.finished = true
      end

      -- any GoTest line closes the exception block before it
      if not failed_suite then
        collecting = nil
      end
    elseif collecting then
      local file, lnum = line:match(FRAME)
      local detail = line:match(DETAIL)

      if file then
        collecting.frames[#collecting.frames + 1] =
          { file = file, line = num(lnum) }
      elseif detail and detail ~= "" and detail ~= "Exception:" then
        -- the first detail line is the exception with its type
        collecting.exception = collecting.exception or detail
      end
    end
  end

  return parsed
end

--- What to show against a failed test
--- @param method godottest.Method
--- @return string
function M.message(method)
  return method.exception or method.message or "test failed"
end

--- Where to put the failure, the innermost frame that lands in the test's own
--- file. GoDotTest gives an exception and a trace
--- Neotest then falls back to the test's own declaration
--- @param method godottest.Method
--- @param path string the test's file
--- @return number? zero-indexed line, the indexing neotest wants
function M.line(method, path)
  for _, frame in ipairs(method.frames) do
    if frame.file == path then
      return frame.line - 1
    end
  end
  return nil
end

return M
