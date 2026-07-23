-- Tabbed, centered floating Claude Code sessions, switched with Alt+1..Alt+9
return require("util.tabterm").new({
  cmd = "claude",
  label = "claude",
  -- the claude statusline reads this and drops its dir and branch segments
  env = { CLAUDE_NVIM_FLOAT = "1" },
  siblings = { "util.terminal" },
})
