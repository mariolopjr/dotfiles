-- <leader>j: pick and run a recipe from the project's justfile

-- what `just` itself looks for, walking up from the file or the cwd
local markers = { "justfile", ".justfile", "Justfile" }

local has_just = vim.fn.executable("just") == 1

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

--- Pick a recipe with snacks and run it in a snacks terminal
--- @param root string The directory to run `just` in
local function pick_just(root)
  local Snacks = require("snacks")
  local dump = vim
    .system({ "just", "--dump", "--dump-format", "json" }, { cwd = root })
    :wait()
  if dump.code ~= 0 then
    vim.notify("no justfile here", vim.log.levels.WARN)
    return
  end
  local ok, parsed = pcall(vim.json.decode, dump.stdout)
  if not ok or type(parsed.recipes) ~= "table" then
    vim.notify("could not parse justfile", vim.log.levels.ERROR)
    return
  end

  local items = {}
  for name, recipe in pairs(parsed.recipes) do
    if not recipe.private then
      items[#items + 1] =
        { text = name, doc = recipe.doc, detached = is_detached(recipe) }
    end
  end
  table.sort(items, function(a, b)
    return a.text < b.text
  end)

  local show_cache = {}
  Snacks.picker.pick({
    source = "just",
    items = items,
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
      if not item then
        return
      end
      if item.detached then
        -- detach into a new session so the process survives nvim tearing down
        -- the terminal job, output is discarded by the recipe itself
        vim.fn.jobstart({ "just", item.text }, { cwd = root, detach = true })
        vim.notify(
          "just " .. item.text .. " launched detached",
          vim.log.levels.INFO
        )
      else
        Snacks.terminal.open({ "just", item.text }, { cwd = root })
      end
    end,
  })
end

--- Map or unmap <leader>j in a buffer based on whether its project has a justfile
--- @param buf integer
local function refresh(buf)
  if
    not has_just
    or not vim.api.nvim_buf_is_valid(buf)
    or vim.bo[buf].buftype ~= ""
  then
    return
  end
  local root = just_root(buf)
  if root then
    vim.keymap.set("n", "<leader>j", function()
      pick_just(root)
    end, { buffer = buf, desc = "[J]ust tasks" })
  else
    pcall(vim.keymap.del, "n", "<leader>j", { buffer = buf })
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
