--- util.godot: opens a godot project in the godot editor

local M = {}

--- project.godot exists at the workspace root (gdscript) or in a graphics/ subdir
--- (graphics.gd/golang)
local markers = {
  "project.godot",
  "graphics/project.godot",
}

--- Locate the godot project
--- @param source string|integer file, directory, or buffer number
--- @return { project: string, workspace: string }?
local function find(source)
  for _, marker in ipairs(markers) do
    local project = vim.fs.root(source, marker)
    if project then
      local sub = vim.fs.dirname(marker)
      return {
        project = project,
        workspace = sub ~= "." and vim.fs.dirname(project) or project,
      }
    end
  end
end

--- Buffer 0 allows vim.fs.root map a special buffer to the cwd
--- @param path string|integer?
--- @return string|integer
local function source(path)
  if path ~= nil and path ~= "" then
    return path
  end
  return 0
end

--- Locate the godot project covering a path
--- @param path string|integer? file, directory, or buffer, defaults to the buffer
--- @return { project: string, workspace: string }?
function M.find(path)
  return find(source(path))
end

--- The godot project directory path
--- @param path string|integer? file, directory, or buffer, defaults to the buffer
--- @return string?
function M.root(path)
  local found = M.find(path)
  return found and found.project or nil
end

--- Build the argv prefix that runs godot
--- $GODOT either is a binary name `godot` or a path to a binary
--- @return string[]? argv, string name
local function launcher()
  local name = vim.env.GODOT
  if name == nil or name == "" then
    name = "godot"
  end

  -- exepath errors on an empty string
  local exe = vim.fn.exepath(name)
  if exe ~= "" then
    return { exe }, name
  end

  -- ensure godot can be ran even if mise is not loaded
  local mise = vim.fn.exepath("mise")
  if mise ~= "" then
    return { mise, "x", "--", name }, name
  end

  return nil, name
end

--- Opens the editor on the project
--- @param project string? project or workspace dir, defaults to the buffer
function M.open_editor(project)
  local found = find(source(project))
  if not found then
    vim.notify("godot: no project for this buffer", vim.log.levels.WARN)
    return
  end

  local cmd, name = launcher()
  if not cmd then
    local msg = "godot: " .. name .. " is not on PATH and mise is not either"
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end
  vim.list_extend(cmd, { "--editor", "--path", found.project })

  local errors = {}
  vim.system(cmd, {
    cwd = found.project,
    detach = true,
    stdout = false,
    stderr = function(_, data)
      if data then
        errors[#errors + 1] = data
      end
    end,
  }, function(obj)
    if obj.code == 0 then
      return
    end
    local detail = table.concat(errors):gsub("%s+$", "")
    vim.schedule(function()
      local msg = ("godot: the editor exited %d"):format(obj.code)
      if detail ~= "" then
        msg = msg .. "\n" .. detail
      end
      vim.notify(msg, vim.log.levels.ERROR)
    end)
  end)

  vim.notify(
    "godot: launching the editor on " .. vim.fs.basename(found.workspace)
  )
end

return M
