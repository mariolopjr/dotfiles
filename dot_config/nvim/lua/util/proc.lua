-- Named singleton background processes with start/stop notifications.
-- Used by the cargo run command

local M = {}

local procs = {}

--- Get or create the process slot for a name
--- @param name string Display name used in notifications
function M.get(name)
  if procs[name] then
    return procs[name]
  end

  local handle
  local proc = {}

  --- @param cmd string
  --- @param args string[]
  --- @param cwd string|nil
  function proc.start(cmd, args, cwd)
    if handle then
      vim.notify(name .. " is already running", vim.log.levels.WARN)
      return
    end
    -- luv's option type marks every field required, they are all optional
    ---@diagnostic disable-next-line: missing-fields
    handle = vim.uv.spawn(cmd, { args = args, cwd = cwd }, function(code)
      handle = nil
      if code ~= 0 then
        vim.schedule(function()
          vim.notify(name .. " exited with code " .. code, vim.log.levels.ERROR)
        end)
      end
    end)
    if handle then
      vim.notify(name .. " started", vim.log.levels.INFO)
    else
      vim.notify("Failed to start " .. name, vim.log.levels.ERROR)
    end
  end

  function proc.stop()
    if not handle then
      vim.notify("No " .. name .. " process running", vim.log.levels.WARN)
      return
    end
    handle:kill("sigterm")
    handle = nil
    vim.notify(name .. " stopped", vim.log.levels.INFO)
  end

  procs[name] = proc
  return proc
end

return M
