local M = {}

local wez = require("wezterm")

local function is_nvim(pane)
  -- this is set by the plugin, and unset on ExitPre in Neovim
  return pane:get_user_vars().IS_NVIM == "true"
end

local direction_keys = {
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

local function split_nav(resize_or_move, key)
  return {
    key = key,
    mods = resize_or_move == "resize" and "SUPER" or "CTRL",
    action = wez.action_callback(function(win, pane)
      if is_nvim(pane) then
        -- pass the keys through to nvim
        win:perform_action({
          SendKey = { key = key, mods = resize_or_move == "resize" and "SUPER" or "CTRL" },
        }, pane)
      else
        if resize_or_move == "resize" then
          win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
        else
          win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
        end
      end
    end),
  }
end

function M.apply_to_config(config)
  config.keys = {
    -- move between split panes
    split_nav("move", "h"),
    split_nav("move", "j"),
    split_nav("move", "k"),
    split_nav("move", "l"),

    -- resize panes
    split_nav("resize", "h"),
    split_nav("resize", "j"),
    split_nav("resize", "k"),
    split_nav("resize", "l"),

    -- split panes
    {
      key = "-",
      mods = "SUPER",
      action = wez.action.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    {
      key = "\\",
      mods = "SUPER",
      action = wez.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
  }
end

return M
