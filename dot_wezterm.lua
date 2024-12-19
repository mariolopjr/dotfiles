-- setup local wezterm APIs
local wezterm = require("wezterm")
local mux = wezterm.mux
local action = wezterm.action

local keymap = require("keymap")

-- config
local config = wezterm.config_builder()

config.term = "wezterm"
config.animation_fps = 240
config.max_fps = 240
config.front_end = "WebGpu"

-- maximize window on launch
wezterm.on("gui-startup", function()
  local _, _, window = mux.spawn_window({})
  window:gui_window():maximize()
end)
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true

-- set theme settings
config.color_scheme = "Catppuccin Macchiato"
config.font = wezterm.font("Iosevka NF", { weight = "Bold", stretch = "Expanded" })
config.font_size = 16

-- set default shell to fish
config.default_prog = { "/opt/homebrew/bin/fish", "-l" }

-- apply keyamp
keymap.apply_to_config(config)

return config
