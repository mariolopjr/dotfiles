--- hoverboard: Better LSP hover docs
---
--- vim.lsp.util.open_floating_preview is wrapped so floats opened for hover,
--- identified by the focus_id their caller passes, get their markdown tidied
--- before the float opens and decorated after. Everything else the float
--- already does natively: treesitter highlights fenced code through language
--- injections and conceals inline markup
---
--- The server behind the float lands in b:hover_server on the float buffer
--- for per-server styling tweaks

local M = {}

local float = require("hoverboard.float")
local highlights = require("hoverboard.highlights")
local synth = require("hoverboard.synth")
local tidy = require("hoverboard.tidy")

--- floats opened by vim.lsp.buf.hover and rustaceanvim's hover actions
local hover_ids = {
  ["textDocument/hover"] = true,
  ["rust-analyzer-hover-actions"] = true,
}

--- Which client produced a hover, rustaceanvim floats carry their own
--- focus_id, native hovers resolve to the first hover-capable client on the
--- source buffer, ambiguous only when several are attached
--- @param focus_id string
--- @return vim.lsp.Client?
local function hover_client(focus_id)
  if focus_id == "rust-analyzer-hover-actions" then
    return vim.lsp.get_clients({ bufnr = 0, name = "rust-analyzer" })[1]
  end
  return vim.lsp.get_clients({
    bufnr = 0,
    method = "textDocument/hover",
  })[1]
end

--- guards re-running setup
local installed = false

function M.setup()
  if installed then
    return
  end
  installed = true

  highlights.apply()
  local group = vim.api.nvim_create_augroup("hoverboard", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = highlights.apply,
  })
  synth.setup(group)

  local open_floating_preview = vim.lsp.util.open_floating_preview
  --- @diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
    if syntax ~= "markdown" or not (opts and hover_ids[opts.focus_id]) then
      return open_floating_preview(contents, syntax, opts)
    end

    -- a reopening peek knows its client and position, deriving them from
    -- the cursor would synthesize headers against the wrong symbol
    local handoff = float.handoff
    float.handoff = nil
    local client = handoff and handoff.client or hover_client(opts.focus_id)
    local params = handoff and handoff.params
      or client
        and vim.lsp.util.make_position_params(0, client.offset_encoding)
    opts = vim.tbl_extend("keep", opts, { border = "rounded", max_width = 90 })

    -- peeks and back steps re-render from the untouched lines
    local raw = vim.list_slice(contents)
    local tidied, table_marks, links = tidy.tidy(contents)
    local lang = tidy.fragment_lang(tidied)
    local pending
    if client and client.name == "rust-analyzer" then
      tidied, pending = synth.apply_cached(tidied, links)
    end

    local buf, win = open_floating_preview(tidied, syntax, opts)

    -- repeat hovers focus the existing float and can return the source
    -- buffer, only decorate the scratch float buffer
    if
      vim.bo[buf].buftype == "nofile" and vim.bo[buf].filetype == "markdown"
    then
      float.populate(buf, win, {
        raw = raw,
        lines = tidied,
        client = client,
        params = params,
        links = links,
        table_marks = table_marks,
        lang = lang,
        pending = pending,
        max_width = opts.max_width,
        history = handoff and handoff.history,
      })
    end
    return buf, win
  end
end

return M
