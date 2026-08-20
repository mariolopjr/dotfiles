--- util.go: locates go module and tools, also supports graphics.gd projects

local godot = require("util.godot")

local M = {}

--- @param bufnr integer?
--- @return string
function M.root(bufnr)
  return vim.fs.root(bufnr or 0, { "go.work", "go.mod", ".git" })
    or vim.fn.getcwd()
end

--- The module directory covering a buffer
--- @param bufnr integer?
--- @return string?
function M.module(bufnr)
  return vim.fs.root(bufnr or 0, { "go.mod" })
end

--- mise installs tools outside GOPATH, and its shims are absent from PATH when
--- nvim starts outside a login shell
--- @param name string
--- @return string?
local function mise_which(name)
  local mise = vim.fn.exepath("mise")
  if mise == "" then
    return nil
  end
  local out = vim.system({ mise, "which", name }, { text = true }):wait()
  if out.code ~= 0 then
    return nil
  end
  local path = vim.trim(out.stdout or "")
  return vim.fn.executable(path) == 1 and path or nil
end

--- @type table<string, string>?
local goenv

--- @param name string
--- @return string?
local function go_env(name)
  if not goenv then
    goenv = {}
    local go = vim.fn.exepath("go")
    if go == "" then
      go = mise_which("go") or ""
    end
    if go ~= "" then
      local cmd = { go, "env", "GOBIN", "GOPATH" }
      local out = vim.system(cmd, { text = true }):wait()
      if out.code == 0 then
        local lines = vim.split(out.stdout or "", "\n", { plain = true })
        goenv.GOBIN = vim.trim(lines[1] or "")
        goenv.GOPATH = vim.trim(lines[2] or "")
      end
    end
  end
  local value = goenv[name]
  if value == nil or value == "" then
    return nil
  end
  return value
end

--- Where `go install` puts a binary
--- @return string?
local function gobin()
  local bin = go_env("GOBIN")
  if bin then
    return bin
  end
  local path = go_env("GOPATH")
  if not path then
    return nil
  end
  -- GOPATH may name several roots but go installs into the first
  local separator = vim.fn.has("win32") == 1 and ";" or ":"
  return vim.fs.joinpath(vim.split(path, separator, { plain = true })[1], "bin")
end

--- Tool lookups shell out so cache the answer
--- @type table<string, string|false>
local resolved = {}

--- Absolute path of a go tool or nil if it doesn't exist
--- @param name string?
--- @return string?
function M.exe(name)
  -- exepath errors on an empty string
  if name == nil or name == "" then
    return nil
  end

  local cached = resolved[name]
  if cached ~= nil then
    return cached or nil
  end

  local found = vim.fn.exepath(name)
  if found == "" then
    local bin = gobin()
    local path = bin and vim.fs.joinpath(bin, name)
    if path and vim.fn.executable(path) == 1 then
      found = path
    else
      found = mise_which(name) or ""
    end
  end

  resolved[name] = found ~= "" and found or false
  return found ~= "" and found or nil
end

--- The go module root of a graphics.gd project
--- @param source string|integer? file, directory, or buffer number
--- @return string?
function M.graphics_root(source)
  local found = godot.find(source)
  -- gdscript keeps project.godot at the workspace root, graphics.gd nests it
  -- in graphics/
  if not found or found.project == found.workspace then
    return nil
  end
  return vim.fs.root(found.workspace, { "go.mod" })
end

--- The gd command
--- @return string?
function M.gd()
  return M.exe("gd")
end

--- What the go layer resolved for this buffer
--- @param bufnr integer?
--- @return string[]
function M.report(bufnr)
  return {
    "root: " .. M.root(bufnr),
    "module: " .. (M.module(bufnr) or "none"),
    "graphics.gd: " .. (M.graphics_root(bufnr) or "none"),
    "go: " .. (M.exe("go") or "none"),
    "gopls: " .. (M.exe("gopls") or "none"),
    "dlv: " .. (M.exe("dlv") or "none"),
    "gd: " .. (M.gd() or "none"),
    "golangci-lint: " .. (M.exe("golangci-lint") or "none"),
  }
end

return M
