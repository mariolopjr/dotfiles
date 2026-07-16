-- <leader>j: pick and run a recipe from the project's justfile
-- <leader>r<letter>: run a recipe directly through its single-letter just alias

-- what `just` itself looks for, walking up from the file or the cwd
local markers = { "justfile", ".justfile", "Justfile" }

local has_just = vim.fn.executable("just") == 1

-- parsed dumps keyed by justfile root, reused until the justfile's mtime changes
local cache = {}

--- Whether a recipe backgrounds its command with a trailing `&`
--- @param recipe table A recipe entry from `just --dump --dump-format json`
--- @return boolean
local function is_detached(recipe)
  local body = recipe.body
  if type(body) ~= "table" or #body == 0 then
    return false
  end
  local line = body[#body]
  if type(line) ~= "table" or #line == 0 then
    return false
  end
  local frag = line[#line]
  if type(frag) ~= "string" then
    return false
  end
  frag = frag:gsub("%s+$", "")
  return frag:sub(-1) == "&" and frag:sub(-2) ~= "&&"
end

--- Whether a recipe requires arguments to run
--- @param recipe table A recipe entry from the dump
--- @return boolean
local function needs_args(recipe)
  for _, param in ipairs(recipe.parameters or {}) do
    -- luanil turns a JSON null default into nil, so a nil default with a
    -- singular or one-or-more (`+`) parameter means at least one arg is required
    if
      param.default == nil
      and (param.kind == "singular" or param.kind == "plus")
    then
      return true
    end
  end
  return false
end

--- Find the directory of the justfile governing a buffer
--- Searches from the buffer's file, falling back to the cwd for nameless
--- buffers like the dashboard or a project opened without a file yet.
--- @param buf integer
--- @return string|nil root
local function just_root(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local from = name ~= "" and name or vim.fn.getcwd()
  return vim.fs.root(from, markers)
end

--- Locate the justfile inside a root and return a token that changes when it does
--- @param root string
--- @return string|nil token
local function change_token(root)
  for _, marker in ipairs(markers) do
    local st = vim.uv.fs_stat(root .. "/" .. marker)
    if st then
      return st.mtime.sec .. "." .. st.mtime.nsec
    end
  end
end

--- Dump and parse a project's justfile, caching until the file changes
--- @param root string The directory to run `just` in
--- @return table|nil data `{ items = <sorted recipes>, aliases = <letter -> recipe> }`
local function load(root)
  local token = change_token(root)
  local cached = cache[root]
  if cached and token and cached.token == token then
    return cached
  end

  local dump = vim
    .system({ "just", "--dump", "--dump-format", "json" }, { cwd = root })
    :wait()
  if dump.code ~= 0 then
    return nil
  end
  -- just emits null for a recipe with no doc comment so convert that to nil
  local ok, parsed = pcall(vim.json.decode, dump.stdout, {
    luanil = { object = true },
  })
  if not ok or type(parsed.recipes) ~= "table" then
    return nil
  end

  local recipes, items = {}, {}
  for name, recipe in pairs(parsed.recipes) do
    if not recipe.private then
      recipes[name] = recipe
      items[#items + 1] = {
        text = name,
        doc = type(recipe.doc) == "string" and recipe.doc or nil,
        recipe = recipe,
      }
    end
  end
  table.sort(items, function(a, b)
    return a.text < b.text
  end)

  -- surface each single-letter alias as <leader>r<letter>, resolving it to its
  -- public target recipe. Multi-letter aliases, private targets, and targets
  -- that need arguments are skipped so the binding always runs cleanly
  local aliases = {}
  if type(parsed.aliases) == "table" then
    for alias, spec in pairs(parsed.aliases) do
      local target = type(spec) == "table" and spec.target
      local recipe = target and recipes[target]
      if alias:match("^%a$") and recipe and not needs_args(recipe) then
        aliases[alias] = recipe
      end
    end
  end

  local data = { token = token, items = items, aliases = aliases }
  cache[root] = data
  return data
end

--- Run a recipe, detaching it if it backgrounds its own command
--- @param root string The directory to run `just` in
--- @param recipe table A recipe entry from the dump
local function run(root, recipe)
  if is_detached(recipe) then
    -- detach into a new session so the process survives nvim tearing down
    -- the terminal job, output is discarded by the recipe itself
    vim.fn.jobstart({ "just", recipe.name }, { cwd = root, detach = true })
    vim.notify(
      "just " .. recipe.name .. " launched detached",
      vim.log.levels.INFO
    )
  else
    require("snacks").terminal.open({ "just", recipe.name }, { cwd = root })
  end
end

--- Pick a recipe with snacks and run it in a snacks terminal
--- @param root string The directory to run `just` in
local function pick_just(root)
  local Snacks = require("snacks")
  local data = load(root)
  if not data then
    vim.notify("could not read justfile", vim.log.levels.WARN)
    return
  end

  local show_cache = {}
  Snacks.picker.pick({
    source = "just",
    items = data.items,
    format = function(item)
      local ret = { { item.text, "SnacksPickerLabel" } }
      if item.doc then
        ret[#ret + 1] = { "  " }
        ret[#ret + 1] = { item.doc, "SnacksPickerComment" }
      end
      return ret
    end,
    preview = function(ctx)
      local item = ctx.item
      if not item then
        return
      end
      ctx.preview:reset()
      ctx.preview:set_title(item.text)
      local body = show_cache[item.text]
      if not body then
        local out = vim
          .system({ "just", "--show", item.text }, { cwd = root })
          :wait()
        body = vim.split(out.stdout or "", "\n")
        show_cache[item.text] = body
      end
      ctx.preview:set_lines(body)
      ctx.preview:highlight({ ft = "just" })
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        run(root, item.recipe)
      end
    end,
  })
end

--- Remove any <leader>r<letter> alias maps this plugin set on a buffer
--- @param buf integer
local function clear_alias_keys(buf)
  local keys = vim.b[buf].just_alias_keys
  if type(keys) == "table" then
    for _, key in ipairs(keys) do
      pcall(vim.keymap.del, "n", "<leader>r" .. key, { buffer = buf })
    end
    vim.b[buf].just_alias_keys = nil
  end
end

--- Map or unmap the just keys in a buffer based on its project's justfile
--- @param buf integer
local function refresh(buf)
  if
    not has_just
    or not vim.api.nvim_buf_is_valid(buf)
    or vim.bo[buf].buftype ~= ""
  then
    return
  end
  clear_alias_keys(buf)
  local root = just_root(buf)
  if not root then
    pcall(vim.keymap.del, "n", "<leader>j", { buffer = buf })
    return
  end

  vim.keymap.set("n", "<leader>j", function()
    pick_just(root)
  end, { buffer = buf, desc = "[J]ust tasks" })

  local data = load(root)
  if not data then
    return
  end
  local keys = {}
  for alias, recipe in pairs(data.aliases) do
    keys[#keys + 1] = alias
    -- mirror the picker's row so the [R]un popup reads `<recipe>  <doc>`
    local desc = type(recipe.doc) == "string"
        and recipe.doc ~= ""
        and recipe.name .. "  " .. recipe.doc
      or recipe.name
    vim.keymap.set("n", "<leader>r" .. alias, function()
      run(root, recipe)
    end, { buffer = buf, desc = desc })
  end
  if #keys > 0 then
    vim.b[buf].just_alias_keys = keys
  end
end

return {
  "folke/snacks.nvim",
  init = function()
    local group = vim.api.nvim_create_augroup("just_recipes", { clear = true })
    -- BufEnter covers every file opened inside a project, DirChanged covers the
    -- project dashboard cd-ing into a project before a file is opened
    vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
      group = group,
      callback = function(ev)
        refresh(ev.buf)
      end,
    })
    -- the startup buffer may already exist before the autocmd is created
    vim.schedule(function()
      refresh(vim.api.nvim_get_current_buf())
    end)
  end,
}
