-- Bottom tab bar styled similarly to the neovim tabline

local palette = require("palette")
local wezterm = require("wezterm")

local M = {}

local FOLDER = wezterm.nerdfonts.fa_folder or "＋"
local TERMINAL = wezterm.nerdfonts.oct_terminal or ">_"

-- foreground process basename to glyph
local ICONS = {
  bash = TERMINAL,
  cargo = wezterm.nerdfonts.dev_rust,
  claude = wezterm.nerdfonts.md_robot,
  docker = wezterm.nerdfonts.linux_docker,
  fish = TERMINAL,
  git = wezterm.nerdfonts.dev_git,
  lua = wezterm.nerdfonts.seti_lua,
  node = wezterm.nerdfonts.dev_nodejs_small,
  nvim = wezterm.nerdfonts.custom_neovim,
  python = wezterm.nerdfonts.dev_python,
  python3 = wezterm.nerdfonts.dev_python,
  rustc = wezterm.nerdfonts.dev_rust,
  ssh = wezterm.nerdfonts.md_lan_connect,
  vim = wezterm.nerdfonts.custom_vim,
  zsh = TERMINAL,
}

local function cells(s)
  return wezterm.column_width(s)
end

local function basename(path)
  if not path or #path == 0 then
    return nil
  end
  return (path:gsub("/+$", "")):match("([^/]+)$")
end

-- label and glyph for a tab
local function tab_label(tab)
  local pane = tab.active_pane
  local proc = basename(pane.foreground_process_name)
  local glyph = proc and ICONS[proc] or TERMINAL
  if tab.tab_title and #tab.tab_title > 0 then
    return tab.tab_title, glyph
  end
  local cwd = pane.current_working_dir
  if cwd and cwd.file_path then
    local p = cwd.file_path:gsub("/+$", "")
    local dir = (p == wezterm.home_dir) and "~" or basename(p)
    if dir then
      return dir, glyph
    end
  end
  return pane.title, glyph
end

-- trailing flag cluster
-- * for unseen output in a background pane
-- Z for a zoomed pane
-- | when the tab holds splits
local function tab_flags(tab)
  local flags = ""
  local count = 1
  local ok, mux_tab = pcall(wezterm.mux.get_tab, tab.tab_id)
  if ok and mux_tab then
    local infos = mux_tab:panes_with_info()
    count = #infos
    for _, info in ipairs(infos) do
      if not info.is_active and info.pane:has_unseen_output() then
        flags = "*"
        break
      end
    end
  end
  if tab.active_pane.is_zoomed then
    flags = flags .. "Z"
  end
  if count > 1 then
    flags = flags .. "|"
  end
  return flags
end

-- fit the various icons and tab name within the tab width
function M.fit(max_width, idx, glyph, label, flag_str)
  local lead = " " .. idx .. " "
  local mid = (glyph ~= "" and glyph ~= nil) and (glyph .. " ") or ""
  local trail = " "
  local function avail()
    return max_width - cells(lead) - cells(mid) - cells(flag_str) - cells(trail)
  end
  if avail() < 3 and mid ~= "" then
    mid = ""
  end
  if avail() < 3 then
    lead = " "
  end
  local room = math.max(avail(), 1)
  if cells(label) > room then
    label = wezterm.truncate_right(label, math.max(room - 1, 1)) .. "…"
  end
  return lead, mid, label, trail
end

wezterm.on("format-tab-title", function(tab, _, _, _, hover, max_width)
  local label, glyph = tab_label(tab)
  local flags = tab_flags(tab)
  local flag_str = #flags > 0 and (" " .. flags) or ""
  local idx = tostring(tab.tab_index + 1)
  local lead, mid, name, trail = M.fit(max_width, idx, glyph, label, flag_str)

  if tab.is_active then
    -- one solid blue block with dark text, matching the neovim active tab
    return {
      { Background = { Color = palette.blue } },
      { Foreground = { Color = palette.base } },
      { Attribute = { Intensity = "Bold" } },
      { Text = lead .. mid .. name .. flag_str .. trail },
    }
  end

  local fill = hover and palette.surface0 or palette.mantle
  local items = {
    { Background = { Color = fill } },
    { Foreground = { Color = palette.green } },
    { Attribute = { Intensity = "Bold" } },
    { Text = lead },
    { Attribute = { Intensity = "Normal" } },
    { Foreground = { Color = palette.text } },
    { Text = mid .. name },
  }
  if flag_str ~= "" then
    items[#items + 1] = { Foreground = { Color = palette.yellow } }
    items[#items + 1] = { Text = flag_str }
  end
  items[#items + 1] = { Foreground = { Color = palette.text } }
  items[#items + 1] = { Text = trail }
  return items
end)

wezterm.on("update-status", function(window, pane)
  local items = {}

  -- peach block while a leader chord is pending
  if window:leader_is_active() then
    items[#items + 1] = { Background = { Color = palette.peach } }
    items[#items + 1] = { Foreground = { Color = palette.base } }
    items[#items + 1] = { Attribute = { Intensity = "Bold" } }
    items[#items + 1] = { Text = " LDR " }
    items[#items + 1] = "ResetAttributes"
  end

  -- non-local domain in mauve, only worth showing when remote
  local domain = pane:get_domain_name()
  if domain ~= "unix" and domain ~= "local" then
    items[#items + 1] = { Background = { Color = palette.mantle } }
    items[#items + 1] = { Foreground = { Color = palette.mauve } }
    items[#items + 1] = { Text = " " .. domain }
  end

  -- workspace chip
  items[#items + 1] = { Background = { Color = palette.mantle } }
  items[#items + 1] = { Foreground = { Color = palette.green } }
  items[#items + 1] = { Attribute = { Intensity = "Bold" } }
  items[#items + 1] =
    { Text = " " .. FOLDER .. " " .. window:active_workspace() }
  items[#items + 1] = "ResetAttributes"

  -- host chip
  local host = wezterm.hostname():match("^[^.]+") or wezterm.hostname()
  items[#items + 1] = { Background = { Color = palette.mantle } }
  items[#items + 1] = { Foreground = { Color = palette.blue } }
  items[#items + 1] = { Text = " " .. host .. " " }

  window:set_right_status(wezterm.format(items))
end)

function M.apply(config)
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = true
  -- always visible, it doubles as the mux status line
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_max_width = 32
  config.show_new_tab_button_in_tab_bar = false
  config.status_update_interval = 1000
  config.colors = {
    tab_bar = { background = palette.mantle },
  }
end

return M
