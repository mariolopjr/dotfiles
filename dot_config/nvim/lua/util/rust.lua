--- util.rust: cargo roots, the codelldb adapter, and godot-rust projects

local godot = require("util.godot")

local M = {}

--- The cargo root covering a path
--- @param source string|integer? file, directory, or buffer, defaults to the buffer
--- @return string?
function M.root(source)
  return vim.fs.root(source or 0, { "Cargo.toml" })
end

--- The cargo root of a godot-rust project
--- @param source string|integer? file, directory, or buffer, defaults to the buffer
--- @return string?
function M.godot_root(source)
  local found = godot.find(source or 0)
  if not found then
    return nil
  end
  -- a graphics.gd project is go
  if found.layout == "graphics" then
    return nil
  end
  return vim.fs.root(found.workspace, { "Cargo.toml" })
end

--- The cargo root of a godot-rust project carrying the in-engine itest harness,
--- the ITestRunner scene that `just test-godot` runs
--- @param source string|integer? file, directory, or buffer, defaults to the buffer
--- @return string?
function M.itest_root(source)
  local found = godot.find(source or 0)
  if not found or found.layout == "graphics" then
    return nil
  end
  if not vim.uv.fs_stat(vim.fs.joinpath(found.project, "itest.tscn")) then
    return nil
  end
  return vim.fs.root(found.workspace, { "Cargo.toml" })
end

--- codelldb from .chezmoiexternal, unpacked as a vsix
--- @return string dir
local function codelldb_dir()
  return vim.fn.expand("~/.local/share/codelldb")
end

--- In order for codelldb to render rust values properly, formatters from the
--- active toolchain need to have each type definition inlined manually
--- @param cfg table dap configuration
--- @param on_config fun(cfg: table)
local function enrich(cfg, on_config)
  local final = vim.deepcopy(cfg)
  local sysroot = vim
    .system({ "rustc", "--print", "sysroot" }, { cwd = cfg.cwd, text = true })
    :wait()
  local root = vim.trim(sysroot.stdout or "")
  if sysroot.code == 0 and root ~= "" then
    local etc = root .. "/lib/rustlib/etc"
    local cmds = { 'command script import "' .. etc .. '/lldb_lookup.py"' }
    if vim.fn.filereadable(etc .. "/lldb_commands") == 1 then
      for _, line in ipairs(vim.fn.readfile(etc .. "/lldb_commands")) do
        local t = vim.trim(line)
        if t ~= "" and t:sub(1, 1) ~= "#" then
          cmds[#cmds + 1] = t
        end
      end
    end
    final.initCommands = vim.list_extend(final.initCommands or {}, cmds)
  end
  on_config(final)
end

--- The debug adapter rust debugs through, codelldb when it has been fetched and
--- the llvm keg's lldb-dap until then. Both get the toolchain's formatters
--- @return table adapter
function M.adapter()
  local dir = codelldb_dir()
  local codelldb = dir .. "/adapter/codelldb"

  --- @type table
  local adapter
  if vim.fn.executable(codelldb) == 1 then
    local libext = vim.uv.os_uname().sysname == "Linux" and ".so" or ".dylib"
    adapter = require("rustaceanvim.config").get_codelldb_adapter(
      codelldb,
      dir .. "/lldb/lib/liblldb" .. libext
    )
  else
    local lldb_dap = vim.fn.exepath("lldb-dap")
    if lldb_dap == "" then
      lldb_dap = "/opt/homebrew/opt/llvm/bin/lldb-dap"
    end
    adapter = { type = "executable", command = lldb_dap, name = "lldb" }
  end
  adapter.enrich_config = enrich

  return adapter
end

--- What the rust layer resolved for this buffer
--- @param bufnr integer?
--- @return string[]
function M.report(bufnr)
  local found = godot.find(bufnr or 0)
  local codelldb = codelldb_dir() .. "/adapter/codelldb"
  local features = vim.g.rustanalyzer_features

  return {
    "cargo: " .. (M.root(bufnr) or "none"),
    "godot project: " .. (found and found.project or "none"),
    "godot layout: " .. (found and found.layout or "none"),
    "itest harness: " .. (M.itest_root(bufnr) or "none"),
    "features: " .. (features and vim.inspect(features) or "default"),
    "adapter: "
      .. (
        vim.fn.executable(codelldb) == 1 and codelldb
        or vim.fn.exepath("lldb-dap")
      ),
    "just: "
      .. (vim.fn.exepath("just") ~= "" and vim.fn.exepath("just") or "none"),
  }
end

return M
