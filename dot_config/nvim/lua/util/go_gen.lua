--- util.go_gen: generating the method stubs that implement an interface

local M = {}

local go = require("util.go")

--- The node of a given type enclosing the cursor
--- @param bufnr integer
--- @param types table<string, boolean>
--- @return TSNode?
local function enclosing(bufnr, types)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "go")
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse()[1]
  if not tree then
    return nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local node =
    tree:root():named_descendant_for_range(row - 1, col, row - 1, col)
  while node do
    if types[node:type()] then
      return node
    end
    node = node:parent()
  end
  return nil
end

--- The type name behind any pointer wrapper
--- @param node TSNode?
--- @param bufnr integer
--- @return string?
local function type_name(node, bufnr)
  while node do
    local t = node:type()
    if t == "type_identifier" then
      return vim.treesitter.get_node_text(node, bufnr)
    elseif t == "pointer_type" or t == "generic_type" then
      node = node:named_child(0)
    else
      return nil
    end
  end
  return nil
end

--- The named type the cursor sits in, whether it is written as a declaration
--- or as the receiver of one of its methods
--- @param bufnr integer
--- @return string? name
--- @return string? recv a lowercased initial, the way go names a receiver
function M.enclosing_type(bufnr)
  local node = enclosing(bufnr, { type_spec = true, method_declaration = true })
  if not node then
    return nil
  end

  local name
  if node:type() == "method_declaration" then
    local recv = node:field("receiver")[1]
    for child in (recv or node):iter_children() do
      if child:type() == "parameter_declaration" then
        name = type_name(child:field("type")[1], bufnr)
        break
      end
    end
  else
    local n = node:field("name")[1]
    name = n and vim.treesitter.get_node_text(n, bufnr) or nil
  end

  if not name then
    return nil
  end
  return name, name:sub(1, 1):lower()
end

--- Append the method stubs implementing an interface for the type under the
--- cursor
--- @param bufnr integer?
function M.impl(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local name, recv = M.enclosing_type(bufnr)
  if not name then
    return vim.notify("go: no type under the cursor", vim.log.levels.WARN)
  end

  local exe = go.exe("impl")
  if not exe then
    return vim.notify("go: impl is not installed", vim.log.levels.ERROR)
  end

  local iface = vim.fn.input("Interface to implement: ")
  if iface == "" then
    return
  end

  vim.system(
    { exe, ("%s *%s"):format(recv, name), iface },
    { text = true, cwd = go.module(bufnr) or vim.fn.getcwd() },
    function(res)
      vim.schedule(function()
        if res.code ~= 0 or vim.trim(res.stdout or "") == "" then
          local err = (res.stderr or ""):match("[^\n]+") or "failed"
          return vim.notify("impl: " .. err, vim.log.levels.ERROR)
        end
        local lines = vim.split(vim.trim(res.stdout), "\n", { plain = true })
        table.insert(lines, 1, "")
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
        vim.notify(("impl: %s implements %s"):format(name, iface))
      end)
    end
  )
end

return M
