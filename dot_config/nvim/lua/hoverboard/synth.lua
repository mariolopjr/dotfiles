--- Signature synthesis for rust-analyzer hovers
---
--- Headers are enriched from the definition site: a `proc_macro name` line
--- becomes the underlying function signature and a method gains its `impl Type`
--- context, both retrieved by the rust treesitter parser. Results are cached
--- for the session, registry sources are version pinned. Cache hits are
--- spliced in before the float opens, misses resolve through one async
--- textDocument/definition request that patches the open float. The proc macros
--- a buffer uses are resolved ahead of time so first hovers already hit the cache:
--- buffers queue on attach and fill the cache once their client finishes its
--- first analysis pass, signalled by rust-analyzer's experimental/serverStatus
--- quiescent flag (rustaceanvim negotiates the capability) or by all of its
--- $/progress work ending

local M = {}

local decorate = require("hoverboard.decorate")

--- synthesized signatures for the session, `pm:<name>` holds a proc macro's
--- function signature, `impl:<crate>\0<signature>` holds a method's impl
--- context or false once the definition proved there is none
--- @type table<string, string[]|false>
local synth_cache = {}

--- proc macro usages in a rust buffer: attribute macros, derives and
--- function-like invocations
local macro_query = [[
  (attribute_item (attribute (identifier) @macro))
  (attribute_item
    (attribute
      (identifier) @_derive
      arguments: (token_tree (identifier) @macro))
    (#eq? @_derive "derive"))
  (macro_invocation macro: (identifier) @macro)
]]

--- @param lines string[]
--- @param srow integer 0 based node start
--- @param scol integer
--- @param erow integer 0 based start of the excluded body
--- @param ecol integer
--- @return string[]?
local function slice(lines, srow, scol, erow, ecol)
  local out
  if erow == srow then
    out = { lines[srow + 1]:sub(scol + 1, ecol) }
  else
    out = { lines[srow + 1]:sub(scol + 1) }
    for r = srow + 2, erow do
      out[#out + 1] = lines[r]
    end
    out[#out + 1] = lines[erow + 1]:sub(1, ecol)
  end

  -- drop the whitespace left where the body began
  out[#out] = out[#out]:gsub("%s+$", "")
  if out[#out] == "" then
    out[#out] = nil
  end
  return #out > 0 and out or nil
end

--- Extract a function signature, everything before the body, from rust
--- source at a definition position, along with the header of the impl block
--- containing it if there is one
--- @param text string
--- @param row integer 0 based
--- @param col integer 0 based
--- @return string[]? signature
--- @return string[]? impl context
function M.extract_signature(text, row, col)
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, "rust")
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local node = tree:root():named_descendant_for_range(row, col, row, col)
  while node and node:type() ~= "function_item" do
    node = node:parent()
  end
  if not node then
    return nil
  end
  local body = node:field("body")[1]
  if not body then
    return nil
  end

  local lines = vim.split(text, "\n", { plain = true })
  local srow, scol = node:range()
  local brow, bcol = body:range()
  local sig = slice(lines, srow, scol, brow, bcol)

  local impl
  local anc = node:parent()
  while anc and anc:type() ~= "impl_item" do
    anc = anc:parent()
  end
  local anc_body = anc and anc:field("body")[1]
  if anc and anc_body then
    local isrow, iscol = anc:range()
    local ibrow, ibcol = anc_body:range()
    impl = slice(lines, isrow, iscol, ibrow, ibcol)
  end

  return sig, impl
end

--- Resolve the definition under params and lift signature and impl context
--- out of its source file. failed marks answers a retry may still turn
--- around, a clean resolution with nothing to lift is a definitive negative
--- @param client vim.lsp.Client
--- @param params table
--- @param cb fun(sig: string[]?, impl: string[]?, failed: boolean?)
local function resolve_definition(client, params, cb)
  local sent = client:request(
    "textDocument/definition",
    params,
    function(err, result)
      if err then
        return cb(nil, nil, true)
      end
      if not result then
        return cb(nil, nil)
      end
      local loc = vim.islist(result) and result[1] or result
      local uri = loc and (loc.targetUri or loc.uri)
      local range = loc and (loc.targetSelectionRange or loc.range)
      if not uri or not range then
        return cb(nil, nil)
      end

      local f = io.open(vim.uri_to_fname(uri), "r")
      if not f then
        return cb(nil, nil, true)
      end
      local text = f:read("*a")
      f:close()

      cb(M.extract_signature(text, range.start.line, range.start.character))
    end
  )
  if not sent then
    cb(nil, nil, true)
  end
end

--- @param line string a `proc_macro ...` hover line
--- @return string?
local function macro_name(line)
  local rest = line:match("^proc_macro%s+(.+)$")
  if not rest then
    return nil
  end
  return rest:match("^derive%(([%w_]+)%)") or rest:match("^([%w_]+)")
end

--- Locate the signature panel in tidied hover lines
--- @param lines string[]
--- @return integer? index of the signature line, 1 based
--- @return string? crate path line
local function find_signature(lines)
  local open
  for i, line in ipairs(lines) do
    if not open and vim.trim(line):match("^```%S") then
      open = i
    elseif open and vim.trim(line) == "```" then
      local sig = i - 1
      if sig > open then
        local crate = sig > open + 1
            and not lines[open + 1]:find("%s")
            and lines[open + 1]
          or nil
        return sig, crate
      end
      return nil
    end
  end
  return nil
end

--- A splice above the doc body moves every link under it
--- @param links { row: integer }[]?
--- @param row integer 1 based first affected row
--- @param delta integer
local function shift_links(links, row, delta)
  for _, l in ipairs(links or {}) do
    if l.row >= row then
      l.row = l.row + delta
    end
  end
end

--- Splice cached synthesis into tidied hover lines before the float opens,
--- report what the async pass still has to resolve. Link rows are shifted
--- along with the splice
--- @param lines string[]
--- @param links { row: integer }[]?
--- @return string[] lines
--- @return { kind: "pm"|"impl", key: string, line: string }? pending
function M.apply_cached(lines, links)
  local sig, crate = find_signature(lines)
  if not sig then
    return lines
  end
  local line = lines[sig]

  if line:match("^proc_macro%s") then
    local name = macro_name(line)
    if not name then
      return lines
    end
    local key = "pm:" .. name
    local cached = synth_cache[key]
    if cached == nil then
      return lines, { kind = "pm", key = key, line = line }
    end
    if cached == false then
      return lines
    end
    local out = {}
    vim.list_extend(out, lines, 1, sig - 1)
    vim.list_extend(out, cached)
    vim.list_extend(out, lines, sig + 1, #lines)
    shift_links(links, sig + 1, #cached - 1)
    return out
  end

  if line:find("%f[%w]fn%f[%W]") and line:find("(", 1, true) then
    local key = "impl:" .. (crate or "") .. "\0" .. line
    local cached = synth_cache[key]
    if cached == nil then
      return lines, { kind = "impl", key = key, line = line }
    end
    if cached == false then
      return lines
    end
    local out = {}
    vim.list_extend(out, lines, 1, sig - 1)
    vim.list_extend(out, cached)
    vim.list_extend(out, lines, sig, #lines)
    shift_links(links, sig, #cached)
    return out
  end

  return lines
end

--- Swap or extend header lines in an open float and refit it. Extmarks
--- below the patch, the link map included, track the edit on their own
--- @param buf integer
--- @param win integer
--- @param row integer 0 based row to patch
--- @param count integer rows to replace, 0 inserts
--- @param new string[]
--- @param max_width integer
local function patch_header(buf, win, row, count, new, max_width)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, row, row + count, false, new)
  vim.bo[buf].modifiable = false

  -- refit for the new longest line, decorate then refits the height
  decorate.refit_width(
    win,
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    max_width
  )
  decorate.decorate(buf, win)
end

--- Resolve a cache miss through the definition site and patch the float,
--- which may be gone or reused by the time the reply lands
--- @param buf integer
--- @param win integer
--- @param client vim.lsp.Client
--- @param params table position params of the hovered symbol
--- @param max_width integer
--- @param pending { kind: "pm"|"impl", key: string, line: string }
function M.synthesize(buf, win, client, params, max_width, pending)
  resolve_definition(client, params, function(sig, impl, failed)
    if pending.kind == "pm" then
      if not sig then
        return
      end
      synth_cache[pending.key] = sig
    else
      if failed then
        return
      end
      synth_cache[pending.key] = impl or false
      if not impl then
        return
      end
    end

    if
      not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win)
    then
      return
    end
    for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 15, false)) do
      if line == pending.line then
        if pending.kind == "pm" then
          patch_header(buf, win, row - 1, 1, sig, max_width)
        else
          patch_header(buf, win, row - 1, 0, impl, max_width)
        end
        return
      end
    end
  end)
end

--- clients that have finished their first analysis pass, definitions are
--- answerable from here on
--- @type table<integer, boolean>
local ready = {}

--- clients whose serverStatus handler has been wrapped
--- @type table<integer, boolean>
local wrapped = {}

--- buffers waiting on their client's first analysis
--- @type table<integer, table<integer, boolean>>
local pending_warm = {}

--- live $/progress tokens per client
--- @type table<integer, integer>
local active_progress = {}

--- cache keys with a cache request in flight, saves in quick succession
--- must not stack duplicates
--- @type table<string, boolean>
local inflight = {}

--- Pre-resolve the proc macros a buffer uses so first hovers hit the cache
--- @param buf integer
--- @param client vim.lsp.Client
local function warm_macros(buf, client)
  local q = decorate.get_query("rust", macro_query)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "rust")
  if not q or not ok or not parser then
    return
  end
  local tree = parser:parse()[1]
  if not tree then
    return
  end

  local seen = {}
  for id, node in q:iter_captures(tree:root(), buf) do
    if q.captures[id] == "macro" then
      local name = vim.treesitter.get_node_text(node, buf)
      local key = "pm:" .. name
      if not seen[name] and synth_cache[key] == nil and not inflight[key] then
        seen[name] = true
        inflight[key] = true
        local srow, scol = node:range()
        resolve_definition(client, {
          textDocument = vim.lsp.util.make_text_document_params(buf),
          position = { line = srow, character = scol },
        }, function(sig, _, failed)
          inflight[key] = nil
          -- negative results stick too, cache runs on every save and only
          -- unresolved names may fire requests. A failed request leaves
          -- the name unresolved so the next pass retries it
          if not failed then
            synth_cache[key] = sig or false
          end
        end)
      end
    end
  end
end

--- A client finished its first analysis pass, cache everything that queued
--- @param client vim.lsp.Client
local function on_ready(client)
  if ready[client.id] then
    return
  end
  ready[client.id] = true
  for buf in pairs(pending_warm[client.id] or {}) do
    if vim.api.nvim_buf_is_valid(buf) then
      warm_macros(buf, client)
    end
  end
  pending_warm[client.id] = nil
end

--- @param group integer autocmd group of the plugin
function M.setup(group)
  -- resolve the buffer's proc macros ahead of the first hover, once the
  -- client can actually answer definition requests
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "rust-analyzer" then
        return
      end

      -- rust-analyzer pushes experimental/serverStatus, quiescent flips
      -- true once the full analysis is ready. rustaceanvim negotiates the
      -- capability and installs a handler, wrap it once per client
      if not wrapped[client.id] then
        wrapped[client.id] = true
        local orig = client.handlers["experimental/serverStatus"]
        client.handlers["experimental/serverStatus"] = function(
          err,
          result,
          ctx
        )
          if result and result.quiescent then
            on_ready(client)
          end
          if orig then
            return orig(err, result, ctx)
          end
        end
      end

      if ready[client.id] then
        warm_macros(args.buf, client)
      else
        local pend = pending_warm[client.id] or {}
        pend[args.buf] = true
        pending_warm[client.id] = pend
      end
    end,
  })

  -- macros written into the buffer since the attach-time cache resolve on
  -- save, the cache keeps already-known names from firing again
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_clients({
        bufnr = args.buf,
        name = "rust-analyzer",
      })[1]
      if client and ready[client.id] then
        warm_macros(args.buf, client)
      end
    end,
  })

  -- fallback readiness signal for servers without serverStatus: when every
  -- $/progress the client reported has ended and stays quiet briefly, the
  -- first analysis pass is done
  vim.api.nvim_create_autocmd("LspProgress", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "rust-analyzer" or ready[client.id] then
        return
      end
      local id = client.id
      local kind = args.data.params.value.kind
      if kind == "begin" then
        active_progress[id] = (active_progress[id] or 0) + 1
      elseif kind == "end" then
        active_progress[id] = math.max(0, (active_progress[id] or 1) - 1)
        if active_progress[id] == 0 then
          -- debounce the gap between chained progress phases
          vim.defer_fn(function()
            if not ready[id] and active_progress[id] == 0 then
              on_ready(client)
            end
          end, 500)
        end
      end
    end,
  })
end

return M
