-- chezmoi diff and apply in centered floating terminals

local M = {}

--- Shared centered float window options
--- @param title string
--- @return snacks.win.Config
local function float(title)
  return {
    position = "float",
    width = 0.9,
    height = 0.9,
    border = "rounded",
    title = title,
    title_pos = "center",
  }
end

--- Show the full pending diff, or report when the target is already in sync
function M.diff()
  vim.system({ "chezmoi", "diff" }, { text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 and vim.trim(res.stdout or "") == "" then
        vim.notify("No changes detected", vim.log.levels.INFO)
        return
      end
      Snacks.terminal.open("chezmoi diff", {
        win = float(" chezmoi diff "),
      })
    end)
  end)
end

--- apply pending changes after confirmation, output stays until dismissed
function M.apply()
  if vim.fn.confirm("Apply pending chezmoi changes?", "&Yes\n&No", 2) ~= 1 then
    return
  end
  local term = Snacks.terminal.open("chezmoi apply -v", {
    win = float(" chezmoi apply "),
    auto_close = false,
  })
  if term and term.buf then
    -- exit terminal mode with <Esc><Esc>q
    vim.keymap.set("n", "q", function()
      term:close()
      vim.cmd.checktime()
    end, { buffer = term.buf, nowait = true, desc = "Close and reload" })
  end
end

--- regenerate the config file and run init scripts, output stays until dismissed
function M.init()
  local term = Snacks.terminal.open("chezmoi init", {
    win = float(" chezmoi init "),
    auto_close = false,
  })
  if term and term.buf then
    -- exit terminal mode with <Esc><Esc>q
    vim.keymap.set("n", "q", function()
      term:close()
    end, { buffer = term.buf, nowait = true, desc = "Close" })
  end
end

return M
