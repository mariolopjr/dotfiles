--- Highlight groups the float styling utilizes:
---   HoverCodeBlock    code block band, blended from the float background
---   HoverInlineCode   inline code chip, same blend, keeps the syntax color
---   HoverHeading      heading text, foreground bold
---   HoverCratePath    crate path line of the signature panel, Comment
---   HoverRule         thematic break line, WinSeparator
---   HoverTableBorder  table border glyphs, text foreground
---   HoverBold         flattened bold table cell text
---   HoverLink         follow-able reference, underline over whatever color
---                     the span already has

local M = {}

--- @param color integer
--- @param shift integer
--- @return integer
local function channel(color, shift)
  return math.floor(color / 2 ^ shift) % 256
end

--- Mix two 24 bit colors, alpha is used to blend in the second color
--- @param from integer
--- @param to integer
--- @param alpha number
--- @return integer
local function blend(from, to, alpha)
  local out = 0
  for _, shift in ipairs({ 16, 8, 0 }) do
    local mixed = channel(from, shift) * (1 - alpha)
      + channel(to, shift) * alpha
    out = out + math.floor(mixed + 0.5) * 2 ^ shift
  end
  return out
end

--- Groups like ColorColumn are tuned against the editor background, on a
--- float whose background differs they contrast too much, so nudge the
--- float's own background a step toward the foreground instead
function M.apply()
  local float = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local bg = float.bg or normal.bg
  local fg = float.fg or normal.fg
  if bg and fg then
    local band = blend(bg, fg, 0.06)
    vim.api.nvim_set_hl(0, "HoverCodeBlock", { bg = band })
    vim.api.nvim_set_hl(0, "HoverInlineCode", { bg = band })
    vim.api.nvim_set_hl(0, "HoverHeading", { fg = fg, bold = true })
    vim.api.nvim_set_hl(0, "HoverTableBorder", { fg = fg })
  else
    vim.api.nvim_set_hl(0, "HoverCodeBlock", { link = "ColorColumn" })
    vim.api.nvim_set_hl(0, "HoverInlineCode", { link = "ColorColumn" })
    vim.api.nvim_set_hl(0, "HoverHeading", { link = "Title" })
    vim.api.nvim_set_hl(0, "HoverTableBorder", { link = "NormalFloat" })
  end
  vim.api.nvim_set_hl(0, "HoverCratePath", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "HoverRule", { link = "WinSeparator", default = true })
  vim.api.nvim_set_hl(0, "HoverBold", { bold = true, default = true })
  vim.api.nvim_set_hl(0, "HoverLink", { underline = true, default = true })
end

return M
