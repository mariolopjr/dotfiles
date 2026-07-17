--- Resolving a hover doc reference to source locations through the origin
--- client
---
--- rustdoc intra-doc links carry item paths, prose carries bare names, both
--- funnel through workspace/symbol. The search is fuzzy so results filter
--- back to exact names, each hit is chased through textDocument/definition
--- so re-exports collapse onto the one declaration they point at, and a
--- member after the type resolves by documentSymbol on the target file

local M = {}

--- Per-server query decoration. rust-analyzer's workspace/symbol markers: a
--- trailing # limits the search to types, * widens it to dependencies,
--- which need workspace.symbol.search.limit raised so that shorter symbols
--- can still appear
local servers = {
  ["rust-analyzer"] = {
    sep = "::",
    type_query = function(name)
      return name .. "#*"
    end,
    any_query = function(name)
      return name .. "*"
    end,
  },
}

local fallback = {
  sep = ".",
  type_query = function(name)
    return name
  end,
  any_query = function(name)
    return name
  end,
}

--- @param name string client name
function M.server(name)
  return servers[name] or fallback
end

--- @param target string
--- @return boolean
function M.is_url(target)
  return target:match("^%a[%w+.%-]*://") ~= nil
end

--- Map a rustdoc url back onto an item path. Links the server could
--- resolve arrive rewritten as docs.rs or doc.rust-lang.org pages
--- Returns nil for anything that is not a rustdoc item page, primitives included
--- @param url string
--- @return string?
function M.from_url(url)
  local path = url:match("^https?://[^/?#]+/([^?#]*)")
  if not path then
    return nil
  end

  local segs = vim.split(path, "/", { plain = true, trimempty = true })
  local kind, name = (segs[#segs] or ""):match("^(%l+)%.([%w_]+)%.html$")
  if not kind or kind == "primitive" then
    return nil
  end

  -- module segments carry scoring context, version and channel segments do
  -- not read as module names and drop out. Channels read exactly like
  -- module names and need their own list
  local channels = { stable = true, beta = true, nightly = true, latest = true }
  local parts = {}
  for i = 1, #segs - 1 do
    if not channels[segs[i]] and segs[i]:match("^[a-z_][a-z0-9_]*$") then
      parts[#parts + 1] = segs[i]
    end
  end
  parts[#parts + 1] = name

  -- method, tymethod, variant, structfield and associated item anchors all
  -- name the member after their own kind tag
  local fragment = url:match("#(.+)$")
  parts[#parts + 1] = fragment and fragment:match("^%l+%.([%w_]+)$")
  return table.concat(parts, "::")
end

--- Split a path into the type-shaped anchor to search for and the member
--- after it. Anchoring on the last uppercase segment sidesteps crate::
--- prefixes and re-export facades alike, an all-lowercase path anchors on
--- its final segment
--- @param target string
--- @param sep string
--- @return string? anchor
--- @return string? member
--- @return string[] segments
function M.parse(target, sep)
  local segments = vim.split(target, sep, { plain = true })
  for i = #segments, 1, -1 do
    if segments[i]:match("^%u") then
      return segments[i], segments[i + 1], segments
    end
  end
  local last = segments[#segments]
  return last ~= "" and last or nil, nil, segments
end

--- Chase symbol hits through definition so re-exports land on the one
--- declaration behind them, then prefer candidates whose file path mentions
--- the other path segments
--- @param client vim.lsp.Client
--- @param syms table[] workspace/symbol hits, all named alike
--- @param segments string[]
--- @param cb fun(locs: { uri: string, range: table }[])
local function chase(client, syms, segments, cb)
  local landed = {}
  local order = {}
  local remaining = #syms

  local function finish()
    if #order <= 1 then
      return cb(order)
    end
    local score = {}
    for _, loc in ipairs(order) do
      score[loc] = 0
      for _, seg in ipairs(segments) do
        if seg ~= "crate" and loc.uri:find(seg, 1, true) then
          score[loc] = score[loc] + 1
        end
      end
    end
    table.sort(order, function(a, b)
      return score[a] > score[b]
    end)
    -- a strict winner resolves alone, ties go to the caller's picker
    if score[order[1]] > score[order[2]] then
      return cb({ order[1] })
    end
    cb(order)
  end

  local function done()
    remaining = remaining - 1
    if remaining == 0 then
      finish()
    end
  end

  for _, s in ipairs(syms) do
    local sent = client:request("textDocument/definition", {
      textDocument = { uri = s.location.uri },
      position = s.location.range.start,
    }, function(err, result)
      local loc = not err
        and result
        and (vim.islist(result) and result[1] or result)
      local uri = loc and (loc.targetUri or loc.uri) or s.location.uri
      local range = loc and (loc.targetSelectionRange or loc.range)
        or s.location.range
      local key = uri .. ":" .. range.start.line
      if not landed[key] then
        landed[key] = true
        order[#order + 1] = { uri = uri, range = range }
      end
      done()
    end)
    -- a request that never went out has no reply coming
    if not sent then
      done()
    end
  end
end

--- Resolve a reference to the locations it can mean. More than one location
--- survives only when scoring cannot separate them, the member is handed
--- back for M.member once the caller has chosen
--- @param client vim.lsp.Client
--- @param target string path or bare name
--- @param cb fun(locs: { uri: string, range: table }[], member: string?, anchor: string?)
function M.resolve(client, target, cb)
  local server = M.server(client.name)
  local anchor, member, segments = M.parse(target, server.sep)
  if not anchor then
    return cb({})
  end

  local query = anchor:match("^%u") and server.type_query(anchor)
    or server.any_query(anchor)
  local sent = client:request(
    "workspace/symbol",
    { query = query },
    function(err, syms)
      if err or type(syms) ~= "table" then
        return cb({})
      end
      local exact = {}
      for _, s in ipairs(syms) do
        -- the fuzzy search subsequence-matches wildly, exact names only, and
        -- hits without a range need another resolve round trip so skip them
        if s.name == anchor and s.location and s.location.range then
          exact[#exact + 1] = s
          if #exact == 8 then
            break
          end
        end
      end
      if #exact == 0 then
        return cb({})
      end
      chase(client, exact, segments, function(locs)
        cb(locs, member, anchor)
      end)
    end
  )
  if not sent then
    cb({})
  end
end

--- Find a member inside the file that declares the resolved type. Matches
--- nested under a container naming the anchor win over same-named members
--- of other items in the file, and a member that never resolves falls back
--- to the type itself
--- @param client vim.lsp.Client
--- @param loc { uri: string, range: table }
--- @param anchor string?
--- @param name string
--- @param cb fun(loc: { uri: string, range: table })
function M.member(client, loc, anchor, name, cb)
  local sent = client:request("textDocument/documentSymbol", {
    textDocument = { uri = loc.uri },
  }, function(err, syms)
    if err or type(syms) ~= "table" then
      return cb(loc)
    end

    local best
    --- @param list table[]
    --- @param container string?
    --- @return boolean found an anchored match, stop walking
    local function walk(list, container)
      for _, s in ipairs(list) do
        -- hierarchical DocumentSymbol carries selectionRange and children,
        -- flat SymbolInformation carries location and containerName
        local range = s.selectionRange or (s.location and s.location.range)
        local uri = s.location and s.location.uri or loc.uri
        if s.name == name and range then
          local under = container or s.containerName
          if anchor and under and under:find(anchor, 1, true) then
            best = { uri = uri, range = range }
            return true
          end
          best = best or { uri = uri, range = range }
        end
        if s.children and walk(s.children, s.name) then
          return true
        end
      end
      return false
    end
    walk(syms, nil)
    cb(best or loc)
  end)
  if not sent then
    cb(loc)
  end
end

return M
