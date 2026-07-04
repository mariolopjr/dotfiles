local wezterm = require("wezterm")

local config = wezterm.config_builder()

require("appearance").apply(config)
require("domains").apply(config)
require("tabbar").apply(config)
require("keys").apply(config)

return config
