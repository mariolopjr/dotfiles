-- tmux-style tabline for neovim tab pages

local M = {}

local TABLINE = "%!v:lua.require'util.tabline'.render()"

local MODIFIED = "*"
local FOLDER = vim.fn.nr2char(0xf07b) -- nf-fa-folder
local TERMINAL = vim.fn.nr2char(0xf489) -- nf-oct-terminal

-- macchiato values, used as a fallback when the palette is not yet loaded
local FALLBACK = {
  green = "#a6da95",
  blue = "#8aadf4",
  yellow = "#eed49f",
  text = "#cad3f5",
  base = "#24273a",
  mantle = "#1e2030",
  overlay0 = "#6e738d",
}

-- the resolved palette, rebuilt by set_hl so it tracks the active colorscheme
local PAL

-- escape user text so filenames containing % are not read as format items
local function esc(s)
  return (tostring(s):gsub("%%", "%%%%"))
end

local function palette()
  local ok, mod = pcall(require, "catppuccin.palettes")
  if ok then
    local p = mod.get_palette()
    if p then
      return p
    end
  end
  return FALLBACK
end

local function set_hl()
  PAL = palette()
  local fill = PAL.mantle
  local hl = function(name, spec)
    vim.api.nvim_set_hl(0, name, spec)
  end
  -- flat inactive tabs, colored text on the fill background like tmux
  hl("TmuxTabFill", { fg = PAL.overlay0, bg = fill })
  hl("TmuxTabIdx", { fg = PAL.green, bg = fill, bold = true })
  hl("TmuxTabName", { fg = PAL.text, bg = fill })
  hl("TmuxTabFlag", { fg = PAL.yellow, bg = fill })
  -- the current tab is a solid blue block with dark text, matching the
  -- statusline normal-mode block
  hl("TmuxTabActive", { fg = PAL.base, bg = PAL.blue, bold = true })
  -- right-side project chip
  hl("TmuxTabChip", { fg = PAL.green, bg = fill, bold = true })
end

local function get_icons()
  local ok, mi = pcall(require, "mini.icons")
  return ok and mi or nil
end

-- walk the winlayout tree, a "row" holds windows side by side (a vertical
-- split), a "col" holds them stacked (a horizontal split)
local function scan_layout(node, acc)
  local kind = node[1]
  if kind == "row" or kind == "col" then
    acc[kind] = true
    for _, child in ipairs(node[2]) do
      scan_layout(child, acc)
    end
  end
end

-- | for a vertical split, - for a horizontal split, |- for both
local function split_marker(tabnr)
  local acc = {}
  scan_layout(vim.fn.winlayout(tabnr), acc)
  return (acc.row and "|" or "") .. (acc.col and "-" or "")
end

-- the window whose buffer names the tab, skipping floating popups
local function active_win(tab)
  local win = vim.api.nvim_tabpage_get_win(tab)
  if vim.api.nvim_win_get_config(win).relative == "" then
    return win
  end
  if tab == vim.api.nvim_get_current_tabpage() then
    local prev = vim.fn.win_getid(vim.fn.winnr("#"))
    if
      prev ~= 0
      and vim.api.nvim_win_is_valid(prev)
      and vim.api.nvim_win_get_config(prev).relative == ""
    then
      return prev
    end
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      return w
    end
  end
  return win
end

-- label, glyph, split marker, and modified state for a tab page, keyed off its
-- active window's buffer. the glyph inherits the tab's own text color at render
-- so its shape reads monochrome on both the fill and the active blue block
local function tab_info(tab)
  local win = active_win(tab)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local mi = get_icons()

  local label, glyph = nil, ""
  if vim.bo[buf].buftype == "terminal" then
    label = "terminal"
    glyph = TERMINAL
  elseif name == "" then
    label = "[No Name]"
    if mi then
      glyph = mi.get("file", "")
    end
  else
    label = vim.fn.fnamemodify(name, ":t")
    if mi then
      glyph = mi.get("file", label)
    end
  end

  -- flag any modified buffer among the tab's windows
  local modified = false
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].modified then
      modified = true
      break
    end
  end

  return {
    label = label,
    glyph = glyph,
    split = split_marker(vim.api.nvim_tabpage_get_number(tab)),
    modified = modified,
  }
end

-- the trailing flag cluster, modified marker then split direction
local function flags(info)
  local s = ""
  if info.modified then
    s = s .. MODIFIED
  end
  s = s .. info.split
  if s ~= "" then
    s = " " .. s
  end
  return s
end

function M.render()
  if not PAL then
    set_hl()
  end
  local cur = vim.api.nvim_get_current_tabpage()
  local segs = {}

  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local info = tab_info(tab)
    local active = tab == cur
    -- the active tab is one blue block, inactive tabs use the fill palette
    local idx_hl = active and "TmuxTabActive" or "TmuxTabIdx"
    local name_hl = active and "TmuxTabActive" or "TmuxTabName"
    local flag_hl = active and "TmuxTabActive" or "TmuxTabFlag"

    -- click region, selecting the tab on a mouse click
    segs[#segs + 1] = "%" .. i .. "T"
    segs[#segs + 1] = "%#" .. idx_hl .. "# " .. i .. " "
    if info.glyph ~= "" then
      segs[#segs + 1] = "%#" .. name_hl .. "#" .. info.glyph .. " "
    end
    segs[#segs + 1] = "%#" .. name_hl .. "#" .. esc(info.label)
    local f = flags(info)
    if f ~= "" then
      segs[#segs + 1] = "%#" .. flag_hl .. "#" .. f
    end
    segs[#segs + 1] = "%#" .. name_hl .. "# "
  end

  -- close the click region and fill the rest of the line
  segs[#segs + 1] = "%T%#TmuxTabFill#%="

  -- project chip, the cwd basename (~ at home), mirroring tmux status-right
  local dir = vim.fn.getcwd()
  local cwd = dir == vim.env.HOME and "~" or vim.fn.fnamemodify(dir, ":t")
  if cwd ~= "" then
    segs[#segs + 1] = "%#TmuxTabChip# " .. FOLDER .. " " .. esc(cwd) .. " "
  end

  return table.concat(segs)
end

function M.setup()
  set_hl()
  vim.o.showtabline = 1 -- only shown with two or more tabs
  vim.o.tabline = TABLINE
  -- re-derive the highlights whenever the colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("tmux_tabline", { clear = true }),
    callback = set_hl,
  })
end

return M
