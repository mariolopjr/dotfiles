local wezterm = require("wezterm")

local M = {}

function M.apply(config)
  config.default_workspace = "main"

  -- SSH: and SSHMUX: domains for every host in ~/.ssh/config
  config.ssh_domains = wezterm.default_ssh_domains()
end

-- maximize whichever window the GUI just attached
wezterm.on("gui-attached", function()
  local workspace = wezterm.mux.get_active_workspace()
  for _, window in ipairs(wezterm.mux.all_windows()) do
    if window:get_workspace() == workspace then
      local gui = window:gui_window()
      if gui then
        gui:maximize()
      end
    end
  end
end)

return M
