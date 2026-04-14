-- vscode-whichkey.lua
-- Helix-style leader hint panel for vscode-neovim only.
-- Intercepts <leader> with nowait=true, opens a positioned scratch split,
-- auto-discovers keymaps into a trie, renders hints, dispatches on match.

local M = {}

M.config = {
  position = "bottom", -- "bottom" | "left" | "right"
  height = 12,         -- lines for bottom split
  width = 50,          -- cols for left/right split
  col_width = 22,      -- chars per column in helix render
  cols = 4,            -- hint columns across
}

-- ---------------------------------------------------------------------------
-- Trie utilities
-- ---------------------------------------------------------------------------

-- Normalize a keymap lhs to a plain sequence of chars/tokens.
-- Converts <leader> → the actual leader char, strips <Space> → " ", etc.
local function normalize_lhs(lhs)
  local leader = vim.g.mapleader or " "
  -- replace literal <leader> notation (case-insensitive)
  lhs = lhs:gsub("<[Ll]eader>", leader)
  -- collapse <Space> → space
  lhs = lhs:gsub("<[Ss]pace>", " ")
  return lhs
end

-- Build a trie from a flat list of keymap entries.
-- Each node: { desc=string|nil, rhs=string|nil, callback=func|nil, children={char→node} }
local function new_node()
  return { desc = nil, rhs = nil, callback = nil, children = {} }
end

local function insert_into_trie(root, keys, entry)
  local node = root
  for i = 1, #keys do
    local ch = keys:sub(i, i)
    if not node.children[ch] then
      node.children[ch] = new_node()
    end
    node = node.children[ch]
  end
  node.desc = entry.desc
  node.rhs = entry.rhs
  node.callback = entry.callback
end

function M.build_trie()
  local root = new_node()
  local leader = vim.g.mapleader or " "

  local sources = vim.api.nvim_get_keymap("n")
  local buf_maps = vim.api.nvim_buf_get_keymap(0, "n")
  for _, m in ipairs(buf_maps) do
    sources[#sources + 1] = m
  end

  for _, m in ipairs(sources) do
    if not m.lhs or not m.desc or m.desc == "" then goto continue end
    local norm = normalize_lhs(m.lhs)
    -- only include leader-prefixed maps
    if norm:sub(1, #leader) ~= leader then goto continue end
    local suffix = norm:sub(#leader + 1)
    if suffix == "" then goto continue end
    local entry = {
      desc = m.desc,
      rhs = (m.rhs ~= "" and m.rhs) or nil,
      callback = m.callback or nil,
    }
    insert_into_trie(root, suffix, entry)
    ::continue::
  end

  -- Inject group names from which-key spec if available and running in terminal.
  -- In vscode which-key.nvim is disabled so we skip this.

  return root
end

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------

-- Returns a list of display lines for a trie node's immediate children.
-- Helix format: key  ●  desc (groups) or key  →  desc (leaves)
function M.render(node)
  local entries = {}
  local sorted_keys = {}
  for ch in pairs(node.children) do
    sorted_keys[#sorted_keys + 1] = ch
  end
  table.sort(sorted_keys)

  for _, ch in ipairs(sorted_keys) do
    local child = node.children[ch]
    local is_group = next(child.children) ~= nil
    local icon = is_group and "●" or "→"
    local desc = child.desc or (is_group and "group" or "?")
    entries[#entries + 1] = { key = ch, icon = icon, desc = desc }
  end

  if #entries == 0 then return { "  (no hints registered)" } end

  local col_w = M.config.col_width
  local ncols = M.config.cols
  -- Fit columns to panel width for left/right layouts
  if M.config.position ~= "bottom" then
    ncols = 2
    col_w = math.floor((M.config.width - 2) / ncols)
  end

  local cell_fmt = " %-2s  %s  %-" .. (col_w - 8) .. "s "

  local lines = {}
  local row = {}
  for i, e in ipairs(entries) do
    row[#row + 1] = cell_fmt:format(e.key, e.icon, e.desc:sub(1, col_w - 8))
    if #row == ncols or i == #entries then
      lines[#lines + 1] = table.concat(row)
      row = {}
    end
  end
  return lines
end

-- ---------------------------------------------------------------------------
-- Panel management
-- ---------------------------------------------------------------------------

local _panel = { win = nil, buf = nil }

function M.open_panel(lines)
  local orig_win = vim.api.nvim_get_current_win()

  -- Build the split command
  local cmd
  if M.config.position == "bottom" then
    cmd = "botright " .. M.config.height .. " split"
  elseif M.config.position == "left" then
    cmd = "topleft " .. M.config.width .. " vsplit"
  else -- right
    cmd = "botright " .. M.config.width .. " vsplit"
  end

  vim.cmd(cmd)
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)

  -- Scratch buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true

  -- Window options
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].winfixheight = true
  vim.wo[win].winfixwidth = true

  -- Write a header + hint lines
  local header = " which-key  (Esc to close)"
  local content = { header, string.rep("─", vim.api.nvim_win_get_width(win) - 1) }
  for _, l in ipairs(lines) do content[#content + 1] = l end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false

  _panel.win = win
  _panel.buf = buf

  -- Restore focus to the original window so getcharstr() intercepts correctly
  vim.api.nvim_set_current_win(orig_win)

  return win, buf
end

function M.update_panel(lines)
  if not _panel.win or not vim.api.nvim_win_is_valid(_panel.win) then return end
  local buf = _panel.buf
  vim.bo[buf].modifiable = true
  local header = " which-key  (Esc to close)"
  local width = vim.api.nvim_win_get_width(_panel.win)
  local content = { header, string.rep("─", width - 1) }
  for _, l in ipairs(lines) do content[#content + 1] = l end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
end

function M.close_panel()
  if _panel.win and vim.api.nvim_win_is_valid(_panel.win) then
    vim.api.nvim_win_close(_panel.win, true)
  end
  _panel.win = nil
  _panel.buf = nil
end

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

function M.dispatch(node)
  M.close_panel()
  if node.callback then
    node.callback()
  elseif node.rhs and node.rhs ~= "" then
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes(node.rhs, true, false, true),
      "m",
      false
    )
  end
end

-- ---------------------------------------------------------------------------
-- Main show() loop
-- ---------------------------------------------------------------------------

function M.show()
  local trie = M.build_trie()

  -- No leader maps registered yet (e.g. plugins not loaded)
  if not next(trie.children) then return end

  local lines = M.render(trie)
  M.open_panel(lines)

  local node = trie
  local accumulated = ""

  while true do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok or ch == nil then
      M.close_panel()
      return
    end

    -- Esc or ctrl-c → abort
    if ch == "\27" or ch == "\3" then
      M.close_panel()
      return
    end

    local child = node.children[ch]
    if not child then
      -- No match: close panel and feed the leader + accumulated + unknown key
      -- back so normal Neovim processing handles it
      M.close_panel()
      local leader = vim.g.mapleader or " "
      local replay = leader .. accumulated .. ch
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes(replay, true, false, true),
        "n",
        false
      )
      return
    end

    accumulated = accumulated .. ch

    if next(child.children) then
      -- Group: update panel with this level's hints and keep reading
      M.update_panel(M.render(child))
      node = child
    else
      -- Leaf: execute
      M.dispatch(child)
      return
    end
  end
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

function M.setup(opts)
  if not vim.g.vscode then return end

  if opts then
    for k, v in pairs(opts) do
      M.config[k] = v
    end
  end

  -- Intercept <leader> with nowait so our loop handles all <leader>X dispatch.
  -- Existing <leader>X mappings remain registered for terminal Neovim; in vscode
  -- they are shadowed by this nowait binding.
  vim.keymap.set("n", vim.g.mapleader or " ", M.show, {
    noremap = true,
    nowait = true,
    silent = true,
    desc = "Which-key leader hints (vscode)",
  })
end

return M
