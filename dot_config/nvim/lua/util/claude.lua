-- Toggleable, centered floating Claude Code session

local M = {}

local CMD = "claude"

--- Shared terminal options
--- @return snacks.terminal.Opts
local function opts()
  return {
    cwd = vim.fn.getcwd(-1, -1),
    count = 1,
    -- the claude statusline reads this and drops its dir and branch segments
    env = { CLAUDE_NVIM_FLOAT = "1" },
    win = {
      position = "float",
      width = 0.9,
      height = 0.9,
      border = "rounded",
      title = " claude ",
      title_pos = "center",
    },
  }
end

--- The claude window if one exists, without creating it
--- @return snacks.win?
local function existing()
  return Snacks.terminal.get(
    CMD,
    vim.tbl_deep_extend("force", opts(), { create = false })
  )
end

--- Hide the claude window if it is currently shown
function M.hide()
  local term = existing()
  if term and term:valid() then
    term:hide()
  end
end

--- Toggle the Claude window, starting the session on first open
function M.toggle()
  local term = existing()
  if term and term:valid() then
    -- already shown, hide it and fall back to the editor
    term:hide()
    return
  end

  -- about to show, hide the terminal so the two floats never stack
  require("util.terminal").hide()

  local created
  term, created = Snacks.terminal.get(CMD, opts())
  if not term then
    return
  end
  if created then
    -- Ctrl+hjkl navigates out of the float instead of going to claude
    require("util.termnav").attach(term.buf)
    -- wipe the buffer when claude exits so the next toggle starts a fresh
    -- session instead of showing a dead terminal
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = term.buf,
      once = true,
      callback = function(ev)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            vim.api.nvim_buf_delete(ev.buf, { force = true })
          end
        end)
      end,
    })
    return
  end
  term:show():focus()
end

--- End the running Claude session and close its window
function M.quit()
  local term = existing()
  if not term or not term:buf_valid() then
    vim.notify("no claude session running", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_buf_delete(term.buf, { force = true })
  vim.notify("claude session ended", vim.log.levels.INFO)
end

return M
