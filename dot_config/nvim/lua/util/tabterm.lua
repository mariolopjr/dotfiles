-- Tabbed, centered floating terminal sessions
--
-- Each tab is an independent snacks terminal keyed on its count. Alt-number
-- keys switch to (or create) a tab.
-- Only one float shows at a time, so switching reads as tabs

local M = {}

local MAX = 9

--- @class TabTerm
--- @field switch fun(idx?: integer)
--- @field toggle fun()
--- @field quit fun()
--- @field hide fun()
--- @field current fun(): integer?

--- @param cfg { cmd?: string|string[], label: string, env?: table<string,string>, siblings?: string[] }
--- @return TabTerm
function M.new(cfg)
  local CMD = cfg.cmd
  local LABEL = cfg.label
  local ENV = cfg.env
  local SIBLINGS = cfg.siblings or {}

  -- last focused tab, so a bare toggle reopens the tab you left
  local active = 1

  --- @param idx integer
  --- @return snacks.terminal.Opts
  local function opts(idx)
    return {
      cwd = vim.fn.getcwd(-1, -1),
      count = idx,
      env = ENV,
      win = {
        position = "float",
        width = 0.9,
        height = 0.9,
        border = "rounded",
        title_pos = "center",
      },
    }
  end

  --- Tab `idx` if its buffer exists, without creating it
  --- @param idx integer
  --- @return snacks.win?
  local function get(idx)
    return Snacks.terminal.get(
      CMD,
      vim.tbl_deep_extend("force", opts(idx), { create = false })
    )
  end

  --- Indices of tabs with a live buffer, ascending
  --- @return integer[]
  local function live()
    local out = {}
    for i = 1, MAX do
      local t = get(i)
      if t and t:buf_valid() then
        out[#out + 1] = i
      end
    end
    return out
  end

  --- Rich border title: label alone for one tab, a bracketed bar for more
  --- @param active_idx integer
  --- @return string[][]
  local function tabline(active_idx)
    local ids = live()
    if not vim.tbl_contains(ids, active_idx) then
      ids[#ids + 1] = active_idx
      table.sort(ids)
    end
    local parts = { { " " .. LABEL .. " ", "FloatTitle" } }
    -- surface tab numbers only once a second tab exists
    if #ids > 1 then
      for _, i in ipairs(ids) do
        if i == active_idx then
          parts[#parts + 1] = { "[" .. i .. "]", "FloatTitle" }
        else
          parts[#parts + 1] = { " " .. i .. " ", "Comment" }
        end
      end
      parts[#parts + 1] = { " ", "FloatTitle" }
    end
    return parts
  end

  --- Redraw the shown tab's title, keeping the bar honest after a background
  --- tab exits
  local function refresh()
    for _, i in ipairs(live()) do
      local t = get(i)
      if t and t:valid() then
        t:set_title(tabline(i))
      end
    end
  end

  --- Wire navigation and buffer cleanup into a freshly created tab
  --- @param term snacks.win
  local function on_created(term)
    -- Ctrl+hjkl navigates out of the float instead of into the terminal
    require("util.termnav").attach(term.buf)
    -- wipe the buffer when the process exits so the next open starts fresh
    -- instead of showing a dead terminal
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = term.buf,
      once = true,
      callback = function(ev)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            vim.api.nvim_buf_delete(ev.buf, { force = true })
          end
          refresh()
        end)
      end,
    })
  end

  --- The tab whose buffer holds the focused window, if any
  --- @return integer?
  local function current()
    local buf = vim.api.nvim_get_current_buf()
    for _, i in ipairs(live()) do
      local t = get(i)
      if t and t.buf == buf then
        return i
      end
    end
  end

  --- Point active at a live tab, preferring the current one then the lowest
  --- @return integer
  local function resolve_active()
    local t = get(active)
    if t and t:buf_valid() then
      return active
    end
    active = live()[1] or active
    return active
  end

  local function hide_siblings()
    for _, name in ipairs(SIBLINGS) do
      require(name).hide()
    end
  end

  local self = {}

  --- Hide whichever float in this group is currently shown
  function self.hide()
    for _, i in ipairs(live()) do
      local t = get(i)
      if t and t:valid() then
        t:hide()
      end
    end
  end

  --- Show tab `idx`, creating it on first use. If it is already the focused
  --- window, hide it instead so the same key toggles.
  --- @param idx? integer defaults to the active tab
  function self.switch(idx)
    idx = idx or active

    local term = get(idx)
    if term and term:valid() and current() == idx then
      term:hide()
      return
    end

    -- only one float lives at this position at a time
    self.hide()
    hide_siblings()

    local created
    term, created = Snacks.terminal.get(CMD, opts(idx))
    if not term then
      return
    end
    if created then
      on_created(term)
    end
    active = idx
    term:show():focus()
    term:set_title(tabline(idx))
  end

  --- Toggle this group: hide the shown float, or reopen the active tab
  function self.toggle()
    for _, i in ipairs(live()) do
      local t = get(i)
      if t and t:valid() then
        t:hide()
        return
      end
    end
    self.switch(resolve_active())
  end

  --- End a session and close its float, preferring the focused tab
  function self.quit()
    local idx = current()
      or (get(active) and get(active):buf_valid() and active)
      or live()[1]
    local term = idx and get(idx)
    if not term or not term:buf_valid() then
      vim.notify("no " .. LABEL .. " session running", vim.log.levels.WARN)
      return
    end
    vim.api.nvim_buf_delete(term.buf, { force = true })
    vim.notify(LABEL .. " tab " .. idx .. " ended", vim.log.levels.INFO)
  end

  self.current = current

  return self
end

return M
