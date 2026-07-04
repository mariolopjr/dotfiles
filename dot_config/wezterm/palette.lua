-- grab the catppuccin macchiato theme colors
local wezterm = require("wezterm")

local scheme = wezterm.color.get_builtin_schemes()["Catppuccin Macchiato"]

return {
  base = scheme.background,
  text = scheme.foreground,
  red = scheme.ansi[2],
  green = scheme.ansi[3],
  yellow = scheme.ansi[4],
  blue = scheme.ansi[5],
  pink = scheme.ansi[6],
  teal = scheme.ansi[7],
  peach = scheme.indexed[16],
  rosewater = scheme.indexed[17],
  surface2 = scheme.selection_bg,
  overlay0 = scheme.split,
  crust = scheme.tab_bar.background,
  mantle = scheme.tab_bar.inactive_tab.bg_color,
  surface0 = scheme.tab_bar.new_tab.bg_color,
  -- the active tab carries the default accent
  mauve = scheme.tab_bar.active_tab.bg_color,
}
