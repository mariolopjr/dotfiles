-- Toggleable, centered floating shell terminal

local M = {}

--- Shared terminal options
--- @return snacks.terminal.Opts
local function opts()
  return {
    cwd = vim.fn.getcwd(-1, -1),
    count = 2, -- keep this terminal distinct from the claude window (count 1)
    win = {
      position = "float",
      width = 0.9,
      height = 0.9,
      border = "rounded",
      title = " terminal ",
      title_pos = "center",
    },
  }
end

--- The terminal window if one exists, without creating it
--- @return snacks.win?
local function existing()
  return Snacks.terminal.get(
    nil,
    vim.tbl_deep_extend("force", opts(), { create = false })
  )
end

--- Hide the terminal window if it is currently shown
function M.hide()
  local term = existing()
  if term and term:valid() then
    term:hide()
  end
end

--- Toggle the terminal window, starting a shell on first open
function M.toggle()
  local term = existing()
  if term and term:valid() then
    -- already shown, hide it and fall back to the editor
    term:hide()
    return
  end

  -- about to show, hide claude so the two floats never stack
  require("util.claude").hide()

  local created
  term, created = Snacks.terminal.get(nil, opts())
  if not term then
    return
  end
  if created then
    -- wipe the buffer when the shell exits so the next toggle starts a fresh
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

return M
