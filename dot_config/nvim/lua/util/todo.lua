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
    -- snacks opens `file` as a read only preview, checkmate needs to edit it
    bo = { modifiable = true, readonly = false },
    keys = {
      q = "close",
      -- the todo keymaps live under <leader>x, both checkmate's buffer local
      -- set and the global entry points
      ["?"] = function()
        require("which-key").show({ keys = "<leader>x", loop = true })
      end,
    },
    -- the float is an editable file buffer, flush edits when it closes
    on_close = function(self)
      if vim.api.nvim_buf_is_valid(self.buf) and vim.bo[self.buf].modified then
        vim.api.nvim_buf_call(self.buf, function()
          vim.cmd("silent! write")
        end)
      end
    end,
  })
end

-- roots searched by the cross-project todo picker
M.roots = {
  "~/Code",
  "~/.local/share/chezmoi",
}

-- picker over unchecked todo lines across a set of dirs
local function grep(title, dirs)
  Snacks.picker.grep({
    title = title,
    dirs = dirs,
    glob = { "TODO.md", "todo.md", "*.todo.md" },
    -- unchecked checkbox lines only, matched literally
    search = "- [ ]",
    regex = false,
    live = false,
    need_search = false,
  })
end

-- list open todos in the current project only
function M.grep()
  grep("Project TODOs", { root() })
end

-- list open todos across every TODO.md under the configured roots
function M.grep_all()
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
  grep("All Project TODOs", dirs)
end

-- append a task to the project TODO.md without leaving the current buffer
function M.add()
  vim.ui.input({ prompt = "todo: " }, function(text)
    if not text or text:match("^%s*$") then
      return
    end
    local p = ensure()
    local line = "- [ ] " .. text
    -- go through the buffer when the file is already open
    local buf = vim.fn.bufnr(p)
    if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! write")
      end)
    else
      local lines = vim.fn.readfile(p)
      table.insert(lines, line)
      vim.fn.writefile(lines, p)
    end
    vim.notify("todo added: " .. text, vim.log.levels.INFO)
  end)
end

return M
