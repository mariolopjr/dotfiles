-- Route Alt-number tab switching to whichever float is focused, defaulting to
-- claude from the editor
local M = {}

--- @param idx integer
function M.switch(idx)
  local term = require("util.terminal")
  if term.current() then
    term.switch(idx)
  else
    require("util.claude").switch(idx)
  end
end

return M
