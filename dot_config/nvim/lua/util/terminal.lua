-- Tabbed, centered floating shell terminals. Switched with Alt+1..Alt+9 while
-- a terminal float is focused, routed through util.floats.
return require("util.tabterm").new({
  label = "terminal",
  siblings = { "util.claude" },
})
