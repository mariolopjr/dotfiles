local palette = require("palette")
local wezterm = require("wezterm")

local M = {}

function M.apply(config)
  -- ensure high performance rendering
  config.front_end = "WebGpu"
  config.webgpu_power_preference = "HighPerformance"
  config.max_fps = 120
  config.animation_fps = 120

  -- terminfo compiled by run_onchange_after_13-macos-wezterm, gives undercurl
  -- and styled underlines in neovim
  config.term = "wezterm"

  config.color_scheme = "Catppuccin Macchiato"
  config.bold_brightens_ansi_colors = "BrightAndBold"

  config.font = wezterm.font("JetBrains Mono")
  config.harfbuzz_features = { "calt=1", "zero=1" }
  config.font_size = 16

  config.window_decorations = "RESIZE"
  config.window_padding = { left = 4, right = 4, top = 4, bottom = 0 }
  config.adjust_window_size_when_changing_font_size = false
  config.hide_mouse_cursor_when_typing = true
  config.inactive_pane_hsb = { saturation = 0.95, brightness = 0.82 }

  -- left option is alt for nvim keymaps, right option composes characters
  config.send_composed_key_when_left_alt_is_pressed = false
  config.send_composed_key_when_right_alt_is_pressed = true

  config.default_prog = { "/opt/homebrew/bin/fish", "-l" }
  config.scrollback_lines = 10000
  config.enable_kitty_graphics = true
  config.check_for_updates = false

  -- copy on select without a chorded copy binding
  config.mouse_bindings = {
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "NONE",
      action = wezterm.action.CompleteSelectionOrOpenLinkAtMouseCursor(
        "ClipboardAndPrimarySelection"
      ),
    },
  }

  -- overlays follow the macchiato surfaces
  config.command_palette_bg_color = palette.mantle
  config.command_palette_fg_color = palette.text
  config.command_palette_font_size = 15
  config.char_select_bg_color = palette.mantle
  config.char_select_fg_color = palette.text
end

return M
