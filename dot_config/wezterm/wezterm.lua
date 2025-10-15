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
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_max_width = 30

-- set theme settings
config.color_scheme = "Catppuccin Macchiato"
config.underline_position = -2
config.font = wezterm.font_with_fallback({
  {
    family = "Monaspace Neon",
    harfbuzz_features = {
      "calt", -- variable width / texture healing
      "ss01", -- equals ligatures: ==
      -- "ss02", -- less/greater than ligatures: <=
      "ss03", -- arrow ligatures: ->
      "ss04", -- markup ligatures: </
      "ss05", -- F# ligatures: |>
      "ss06", -- repeating character ligatures: ###
      "ss07", -- colon ligatures: ::
      "ss08", -- period ligatures: ..=
      "ss09", -- less/greater than ligatures with other characters: =<<
      "ss10", -- other tag ligatures: #[
      "liga", -- dynamic spacing for repeating char patterns
    },
  },
  { family = "JetBrains Mono" },
})
config.font_rules = {
  {
    intensity = "Bold",
    font = wezterm.font("Monaspace Xenon"),
  },
  {
    italic = true,
    font = wezterm.font("Monaspace Radon", { style = "Italic" }),
  },
  {
    intensity = "Bold",
    italic = true,
    font = wezterm.font("Monaspace Krypton"),
  },
}
config.font_size = 14

-- set default shell to fish
config.default_prog = { "/opt/homebrew/bin/fish", "-l" }

-- apply keymap
keymap.apply_to_config(config)

return config
