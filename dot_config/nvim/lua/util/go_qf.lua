--- util.go_qf: run a whole-module check and load its diagnostics into the
--- quickfix list

local M = {}

--- `file:line:col: message`, the shape go build and go vet both report in.
--- @param root string
--- @param text string
--- @param type_ string
--- @return table[]
function M.parse_plain(root, text, type_)
  local items, seen = {}, {}
  for line in (text or ""):gmatch("[^\n]+") do
    -- `# hovertest` and `# [hovertest]` begins the block for a package
    if line:sub(1, 1) ~= "#" then
      -- `vet: ./bad.go:6:6: ...` on the first failure only
      line = line:gsub("^%a+:%s+", "", 1)
      local file, lnum, col, msg = line:match("^(.-):(%d+):(%d+):%s*(.+)$")
      if not file then
        file, lnum, msg = line:match("^(.-):(%d+):%s*(.+)$")
        col = "1"
      end
      if file and file ~= "" and lnum then
        -- go names paths relative to the package directory it compiled
        local path = file:sub(1, 1) == "/" and file
          or vim.fs.normalize(vim.fs.joinpath(root, file))
        local key = table.concat({ path, lnum, col, msg }, "\0")
        if not seen[key] then
          seen[key] = true
          items[#items + 1] = {
            filename = path,
            lnum = tonumber(lnum),
            col = tonumber(col) or 1,
            text = msg,
            type = type_,
          }
        end
      end
    end
  end
  return items
end

--- golangci-lint's json report
--- @param root string
--- @param stdout string
--- @return table[]
function M.parse_golangci(root, stdout)
  local ok, report = pcall(vim.json.decode, stdout)
  if not ok or type(report) ~= "table" then
    return {}
  end
  local items = {}
  for _, issue in ipairs(report.Issues or {}) do
    local pos = issue.Pos or {}
    if pos.Filename then
      local path = pos.Filename:sub(1, 1) == "/" and pos.Filename
        or vim.fs.joinpath(root, pos.Filename)
      items[#items + 1] = {
        filename = path,
        lnum = pos.Line or 1,
        col = pos.Column or 1,
        text = ("%s (%s)"):format(issue.Text or "", issue.FromLinter or "?"),
        -- golangci reports severity only when a linter sets one
        type = issue.Severity == "error" and "E" or "W",
      }
    end
  end
  return items
end

--- What each runner is
--- @type table<string, { cmd: string[], parse: fun(root: string, out: string, err: string): table[] }>
local runners = {
  vet = {
    cmd = { "go", "vet", "./..." },
    parse = function(root, _, stderr)
      return M.parse_plain(root, stderr, "W")
    end,
  },
  build = {
    cmd = { "go", "build", "./..." },
    parse = function(root, _, stderr)
      return M.parse_plain(root, stderr, "E")
    end,
  },
  lint = {
    cmd = {
      "golangci-lint",
      "run",
      "--output.json.path=stdout",
      "./...",
    },
    parse = function(root, stdout, _)
      return M.parse_golangci(root, stdout)
    end,
  },
}

--- Run a module-wide check and open the quickfix list on the result
--- @param which "vet"|"build"|"lint"
function M.run(which)
  local runner = runners[which]
  if not runner then
    return vim.notify("go: no runner named " .. which, vim.log.levels.ERROR)
  end

  local util = require("util.go")
  local root = util.module(0) or util.root(0)
  local exe = util.exe(runner.cmd[1])
  if not exe then
    return vim.notify(
      "go: " .. runner.cmd[1] .. " is not installed",
      vim.log.levels.ERROR
    )
  end

  local cmd = vim.list_slice(runner.cmd)
  cmd[1] = exe
  vim.notify("go " .. which .. ": running...")
  vim.system(cmd, { cwd = root, text = true }, function(res)
    local items = runner.parse(root, res.stdout or "", res.stderr or "")
    vim.schedule(function()
      vim.fn.setqflist({}, " ", { title = "go " .. which, items = items })
      if #items > 0 then
        vim.cmd("copen")
        vim.notify(
          ("go %s: %d item%s"):format(which, #items, #items == 1 and "" or "s")
        )
      elseif res.code == 0 then
        vim.notify("go " .. which .. ": clean")
      else
        -- a non-zero exit with nothing parsed means the tool itself failed
        local err = (res.stderr or ""):match("[^\n]+") or "failed"
        vim.notify("go " .. which .. ": " .. err, vim.log.levels.ERROR)
      end
    end)
  end)
end

local installed = false

function M.setup()
  if installed then
    return
  end
  installed = true
  for name in pairs(runners) do
    vim.api.nvim_create_user_command(
      "Go" .. name:gsub("^%l", string.upper),
      function()
        M.run(name)
      end,
      { desc = "go " .. name .. " into the quickfix list" }
    )
  end
end

return M
