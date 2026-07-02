-- winbar for the CodeCompanion chat buffer
-- Shows a streaming spinner, the selected model, shared-context count, and
-- token-window usage when the ACP agent reports it

local M = {}

local WINBAR = "%!v:lua.require'util.cc_winbar'.render()"

-- 1M context window
local CONTEXT_WINDOW = 1000000

local USAGE_WARN = 60
local USAGE_CRIT = 80

local SPINNER =
  { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local SPINNER_MS = 80

local streaming = {}
local timer
local frame = 1

local function get_chat(bufnr)
  local ok, chat_mod = pcall(require, "codecompanion.interactions.chat")
  if not ok then
    return nil
  end
  return chat_mod.buf_get_chat(bufnr)
end

local function esc(s)
  return (tostring(s):gsub("%%", "%%%%"))
end

-- compact a token count
local function human(n)
  if n >= 1e6 then
    return (string.format("%.1f", n / 1e6):gsub("%.0$", "")) .. "M"
  end
  if n >= 1e3 then
    return string.format("%.0fk", n / 1e3)
  end
  return tostring(n)
end

-- model name from the ACP config option
local function model_name(meta)
  local co = meta and meta.config_options
  if co and co.model then
    return co.model.name or co.model.current
  end
  local m = meta and meta.adapter and meta.adapter.model
  if type(m) == "string" and m ~= "" and m ~= "default" then
    return m
  end
  return nil
end

function M.render()
  local bufnr = vim.api.nvim_get_current_buf()
  local chat = get_chat(bufnr)
  if not chat then
    return ""
  end

  local meta = (rawget(_G, "codecompanion_chat_metadata") or {})[bufnr]
  local segs = {}

  -- streaming spinner
  if streaming[bufnr] then
    segs[#segs + 1] = "%#Statement# " .. SPINNER[frame] .. " %*"
  end

  -- adapter and selected model
  local head = (chat.adapter and chat.adapter.formatted_name) or "AI"
  local model = model_name(meta)
  if model then
    head = head .. " · " .. model
  end
  segs[#segs + 1] = "%#Title# " .. esc(head) .. " %*"

  -- shared context items, attached files/buffers/symbols
  local n = (chat.context_items and #chat.context_items) or 0
  if n > 0 then
    segs[#segs + 1] = "%#Comment# " .. n .. " ctx %*"
  end

  -- token-window usage, only present if the agent emits usage_update
  local used = chat.tokens
  if type(used) == "number" and used > 0 then
    local max = CONTEXT_WINDOW
    local pct = math.floor(used / max * 100 + 0.5)
    local pct_hl = pct >= USAGE_CRIT and "DiagnosticError"
      or pct >= USAGE_WARN and "DiagnosticWarn"
      or "DiagnosticOk"
    segs[#segs + 1] = "%#Comment# " .. human(used) .. "/" .. human(max) .. " %*"
    segs[#segs + 1] = "%#" .. pct_hl .. "#" .. pct .. "%% %*"
  end

  return table.concat(segs)
end

local function apply(bufnr)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    pcall(vim.api.nvim_set_option_value, "winbar", WINBAR, { win = win })
  end
end

local function stop_timer_if_idle()
  if next(streaming) ~= nil then
    return
  end
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

local function start_timer()
  if timer then
    return
  end
  timer = vim.uv.new_timer()
  timer:start(
    0,
    SPINNER_MS,
    vim.schedule_wrap(function()
      frame = frame % #SPINNER + 1
      pcall(vim.cmd, "redrawstatus!")
    end)
  )
end

function M.setup()
  local group = vim.api.nvim_create_augroup("cc_winbar", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "CodeCompanionChatCreated", "CodeCompanionChatOpened" },
    callback = function(ev)
      local bufnr = ev.data and ev.data.bufnr
      vim.schedule(function()
        apply(bufnr)
      end)
    end,
  })

  -- start the spinner while a response is streaming
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatSubmitted",
    callback = function(ev)
      local bufnr = ev.data and ev.data.bufnr
      if bufnr then
        streaming[bufnr] = true
        start_timer()
      end
    end,
  })

  -- stop the spinner on completion, refresh on any state change. usage_update
  -- fires no autocmd, so these events also drive the token/context refresh
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = {
      "CodeCompanionChatDone",
      "CodeCompanionChatStopped",
      "CodeCompanionChatClosed",
      "CodeCompanionChatAdapter",
      "CodeCompanionChatModel",
      "CodeCompanionACPConnected",
      "CodeCompanionChatACPConfigChanged",
    },
    callback = function(ev)
      local bufnr = ev.data and ev.data.bufnr
      if bufnr then
        streaming[bufnr] = nil
      end
      stop_timer_if_idle()
      pcall(vim.cmd, "redrawstatus!")
    end,
  })
end

return M
