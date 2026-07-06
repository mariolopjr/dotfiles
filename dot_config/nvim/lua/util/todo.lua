-- Per-project TODO.md helpers

local M = {}

local function root()
  return vim.uv.cwd() or vim.fn.getcwd()
end

local function path()
  return vim.fs.joinpath(root(), "TODO.md")
end

-- create TODO.md with a heading the first time it is opened
local function ensure()
  local p = path()
  if vim.fn.filereadable(p) == 0 then
    vim.fn.writefile({ "# " .. vim.fs.basename(root()) .. " todo", "" }, p)
  end
  return p
end

-- open the project TODO.md in a floating window
function M.open()
  Snacks.win({
    file = ensure(),
    width = 0.8,
    height = 0.85,
    border = "rounded",
    title = " todo ",
    title_pos = "center",
    keys = { q = "close" },
  })
end

-- roots searched by the cross-project todo picker
M.roots = {
  "~/Code",
  "~/.local/share/chezmoi",
}

-- list open todos across every TODO.md under the configured roots
function M.grep()
  local dirs = {}
  for _, d in ipairs(M.roots) do
    d = vim.fs.normalize(d)
    if vim.fn.isdirectory(d) == 1 then
      dirs[#dirs + 1] = d
    end
  end
  if #dirs == 0 then
    vim.notify("no todo roots found", vim.log.levels.WARN)
    return
  end
  Snacks.picker.grep({
    title = "Project TODOs",
    dirs = dirs,
    glob = { "TODO.md", "todo.md", "*.todo.md" },
    -- unchecked checkbox lines only, matched literally
    search = "- [ ]",
    regex = false,
    live = false,
    need_search = false,
  })
end

-- append a task to the project TODO.md without leaving the current buffer
function M.add()
  vim.ui.input({ prompt = "todo: " }, function(text)
    if not text or text:match("^%s*$") then
      return
    end
    local p = ensure()
    local lines = vim.fn.readfile(p)
    table.insert(lines, "- [ ] " .. text)
    vim.fn.writefile(lines, p)
    vim.notify("todo added: " .. text, vim.log.levels.INFO)
  end)
end

return M
