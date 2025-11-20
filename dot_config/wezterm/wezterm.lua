---@type Wezterm
local wezterm = require("wezterm")
local mux = wezterm.mux
local action = wezterm.action

local keymap = require("keymap")

---@type Config
local config = wezterm.config_builder()

config.term = "wezterm"
config.animation_fps = 144
config.max_fps = 144
config.front_end = "WebGpu"

-- maximize window on launch
wezterm.on("gui-startup", function()
  local _, _, window = mux.spawn_window({})
  window:gui_window():maximize()
end)
config.window_decorations = "RESIZE"

-- tab bar config
-- TODO: fix tabs on linux
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_max_width = 30

-- set theme settings
config.color_scheme = "Catppuccin Macchiato"
config.font = wezterm.font_with_fallback({
  {
    family = "JetBrains Mono",
  },
  -- TODO: add font fallback for font included in most OS
})
config.font_size = 13

-- set default shell to fish
-- TODO: make this compatible on darwin
-- TODO: spawn distrobox instead of local shell
config.default_prog = { "/usr/bin/fish", "-l" }

-- apply keymap
keymap.apply_to_config(config)

return config
