--- profile.gutter: toggleable inline hotspot annotations, multi source
---
--- Each loaded profile is a source (cpu, heap). When on, every buffer whose
--- file has hotspots gets eol virtual text, and a line that is hot in more than
--- one source shows all of them side by side, each tagged and coloured by its
--- own share of the hottest line in that source. The mode is global so newly
--- opened buffers pick it up through a BufWinEnter autocmd

local M = {}

local ns = vim.api.nvim_create_namespace("profile-gutter")
local aug = vim.api.nvim_create_augroup("profile-gutter", { clear = true })

--- kind -> file (absolute) -> line -> hotspot
local by_source = {}
local enabled = false

local TAG = { cpu = "cpu", heap = "mem" }
local ORDER = { cpu = 1, heap = 2 }

--- @param ratio number 0..1 share of the source's hottest line in the file
--- @return string highlight group
local function heat_hl(ratio)
  if ratio >= 0.66 then
    return "ProfileHeatHigh"
  elseif ratio >= 0.33 then
    return "ProfileHeatMid"
  end
  return "ProfileHeatLow"
end

--- @param kind string
--- @param list profile.Hotspot[]
function M.set_source(kind, list)
  local bf = {}
  for _, h in ipairs(list) do
    local f = bf[h.file] or {}
    -- keep the hottest hotspot when a source line has more than one
    if not f[h.line] or f[h.line].value < h.value then
      f[h.line] = h
    end
    bf[h.file] = f
  end
  by_source[kind] = bf
  if enabled then
    M.refresh_all()
  end
end

function M.clear()
  by_source = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      vim.api.nvim_buf_clear_namespace(b, ns, 0, -1)
    end
  end
end

--- @param bufnr integer
function M.apply(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return
  end
  local abs = vim.fs.normalize(name)

  -- collect every source's hotspots for this file, grouped by line, and the
  -- per-source max so each metric is coloured against its own scale
  local per_line, maxv = {}, {}
  for kind, bf in pairs(by_source) do
    local f = bf[abs]
    if f then
      for line, h in pairs(f) do
        per_line[line] = per_line[line] or {}
        table.insert(per_line[line], { kind = kind, h = h })
        maxv[kind] = math.max(maxv[kind] or 1, h.value)
      end
    end
  end

  local last = vim.api.nvim_buf_line_count(bufnr)
  for line, contribs in pairs(per_line) do
    if line >= 1 and line <= last then
      table.sort(contribs, function(a, b)
        return (ORDER[a.kind] or 9) < (ORDER[b.kind] or 9)
      end)
      local vt = { { "  ▏ ", "ProfileGutterDelim" } }
      for i, c in ipairs(contribs) do
        if i > 1 then
          vt[#vt + 1] = { "  ", "ProfileGutterDelim" }
        end
        vt[#vt + 1] = { TAG[c.kind] or c.kind, "ProfileGutterTag" }
        vt[#vt + 1] =
          { " " .. c.h.label, heat_hl(c.h.value / (maxv[c.kind] or 1)) }
      end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line - 1, 0, {
        virt_text = vt,
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end
  end
end

function M.refresh_all()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      M.apply(b)
    end
  end
end

--- @return boolean now_enabled
function M.toggle()
  enabled = not enabled
  if enabled then
    M.refresh_all()
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = aug,
      callback = function(a)
        M.apply(a.buf)
      end,
    })
  else
    vim.api.nvim_clear_autocmds({ group = aug })
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) then
        vim.api.nvim_buf_clear_namespace(b, ns, 0, -1)
      end
    end
  end
  return enabled
end

--- @return boolean
function M.is_enabled()
  return enabled
end

return M
