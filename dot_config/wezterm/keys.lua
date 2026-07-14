local wezterm = require("wezterm")

local act = wezterm.action
local mux = wezterm.mux

local M = {}

-- ctrl+` opens a quick terminal
local function toggle_scratch(win, pane)
  local current = mux.get_active_workspace()
  if current == "scratch" then
    local previous = wezterm.GLOBAL.previous_workspace or "default"
    -- GLOBAL is an untyped store, this key only ever holds a workspace name
    ---@cast previous string
    win:perform_action(act.SwitchToWorkspace({ name = previous }), pane)
    return
  end
  wezterm.GLOBAL.previous_workspace = current
  win:perform_action(
    act.SwitchToWorkspace({
      name = "scratch",
      spawn = { cwd = wezterm.home_dir },
    }),
    pane
  )
end

local function workspace_picker(window, pane)
  local current = mux.get_active_workspace()
  local choices = {}
  for _, name in ipairs(mux.get_workspace_names()) do
    choices[#choices + 1] = {
      id = name,
      label = name == current and name .. " (current)" or name,
    }
  end
  window:perform_action(
    act.InputSelector({
      title = "workspaces",
      choices = choices,
      fuzzy = true,
      fuzzy_description = "workspace: ",
      action = wezterm.action_callback(function(win, p, id)
        if id then
          win:perform_action(act.SwitchToWorkspace({ name = id }), p)
        end
      end),
    }),
    pane
  )
end

local rename_tab = act.PromptInputLine({
  description = "tab name",
  action = wezterm.action_callback(function(window, _, line)
    if line and #line > 0 then
      window:active_tab():set_title(line)
    end
  end),
})

local rename_workspace = act.PromptInputLine({
  description = "workspace name",
  action = wezterm.action_callback(function(_, _, line)
    if line and #line > 0 then
      mux.rename_workspace(mux.get_active_workspace(), line)
    end
  end),
})

local new_workspace = act.PromptInputLine({
  description = "new workspace",
  action = wezterm.action_callback(function(window, pane, line)
    if line and #line > 0 then
      window:perform_action(
        act.SwitchToWorkspace({
          name = line,
          spawn = { cwd = wezterm.home_dir },
        }),
        pane
      )
    end
  end),
})

function M.apply(config)
  config.leader = { key = ",", mods = "CTRL", timeout_milliseconds = 2000 }

  config.keys = {
    -- Panes
    {
      key = "-",
      mods = "CTRL",
      action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    {
      key = "\\",
      mods = "CTRL",
      action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    {
      key = "x",
      mods = "LEADER",
      action = act.CloseCurrentPane({ confirm = true }),
    },
    { key = "Space", mods = "LEADER", action = act.PaneSelect({}) },
    {
      key = "s",
      mods = "LEADER",
      action = act.PaneSelect({ mode = "SwapWithActive" }),
    },
    { key = "o", mods = "LEADER", action = act.RotatePanes("Clockwise") },

    -- Tabs
    {
      key = "t",
      mods = "SUPER",
      action = act.SpawnCommandInNewTab({ cwd = wezterm.home_dir }),
    },
    {
      key = "c",
      mods = "LEADER",
      action = act.SpawnCommandInNewTab({ cwd = wezterm.home_dir }),
    },
    { key = ",", mods = "LEADER", action = rename_tab },
    { key = ">", mods = "LEADER", action = act.MoveTabRelative(1) },
    { key = "<", mods = "LEADER", action = act.MoveTabRelative(-1) },

    -- Workspaces
    {
      key = "w",
      mods = "LEADER",
      action = wezterm.action_callback(workspace_picker),
    },
    { key = "W", mods = "LEADER", action = new_workspace },
    { key = "$", mods = "LEADER", action = rename_workspace },
    { key = "n", mods = "LEADER", action = act.SwitchWorkspaceRelative(1) },
    { key = "p", mods = "LEADER", action = act.SwitchWorkspaceRelative(-1) },
    {
      key = "d",
      mods = "LEADER",
      action = act.DetachDomain("CurrentPaneDomain"),
    },
    {
      key = "`",
      mods = "CTRL",
      action = wezterm.action_callback(toggle_scratch),
    },
    {
      key = "L",
      mods = "LEADER",
      action = act.ShowLauncherArgs({ flags = "FUZZY|DOMAINS|WORKSPACES" }),
    },

    -- Copy mode, scrollback, config
    { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
    {
      key = "k",
      mods = "SUPER",
      action = wezterm.action_callback(function(win, pane)
        -- nvim owns the whole screen and hosts its own floating terminal,
        -- clearing wezterm's grid corrupts its redraw, so forward the chord
        -- and let nvim clear the inner terminal itself
        if require("plugins.smart-splits").is_vim(pane) then
          -- SendKey encodes with the legacy scheme, which cannot represent
          -- super, so cmd+k would reach nvim as a bare k. write the kitty
          -- keyboard sequence for super+k which nvim decodes it as <D-k>
          win:perform_action(act.SendString("\x1b[107;9u"), pane)
        else
          win:perform_action(
            act.Multiple({
              act.ClearScrollback("ScrollbackAndViewport"),
              act.SendKey({ key = "l", mods = "CTRL" }),
            }),
            pane
          )
        end
      end),
    },
    { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
    { key = "D", mods = "LEADER", action = act.ShowDebugOverlay },
  }

  -- ctrl+hjkl moves and alt+hjkl resizes across wezterm and nvim splits
  require("plugins.smart-splits").apply_to_config(config, {
    direction_keys = { "h", "j", "k", "l" },
    modifiers = { move = "CTRL", resize = "META" },
  })
end

return M
