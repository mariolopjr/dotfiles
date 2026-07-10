-- LSP client management

local M = {}

--- Clients attached to buffers under the cwd, deduped by id and sorted by name
--- Scoping by attached buffer rather than client.root_dir keeps clients with no
--- root_dir like codebook, and drops clients serving another project.
--- @return vim.lsp.Client[]
local function project_clients()
  local cwd = vim.fn.getcwd()
  local seen, clients = {}, {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
      local name = vim.api.nvim_buf_get_name(buf)
      -- relpath resolves a relative target against cwd, so term:// and oil://
      -- names match the project without the absolute path check
      if vim.startswith(name, "/") and vim.fs.relpath(cwd, name) then
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
          if not seen[client.id] then
            seen[client.id] = true
            clients[#clients + 1] = client
          end
        end
      end
    end
  end
  table.sort(clients, function(a, b)
    return a.name < b.name
  end)
  return clients
end

--- @param client vim.lsp.Client
--- @param cwd string
--- @return string
local function short_root(client, cwd)
  if not client.root_dir then
    return ""
  end
  return vim.fs.relpath(cwd, client.root_dir)
    or vim.fn.fnamemodify(client.root_dir, ":~")
end

--- @param client vim.lsp.Client
--- @return string[]
local function details(client)
  local bufs = {}
  for buf in pairs(client.attached_buffers) do
    local name = vim.api.nvim_buf_get_name(buf)
    bufs[#bufs + 1] = "  "
      .. (
        name ~= "" and vim.fn.fnamemodify(name, ":~:.")
        or ("[buf " .. buf .. "]")
      )
  end
  table.sort(bufs)

  local state = "starting"
  if client:is_stopped() then
    state = "stopped"
  elseif client.initialized then
    state = "running"
  end

  -- cmd lives on the config, the client does not carry it
  local cmd = client.config.cmd
  local lines = {
    "id: " .. client.id,
    "name: " .. client.name,
    "state: " .. state,
    "root: " .. (client.root_dir or "(none)"),
    "cmd: "
      .. (type(cmd) == "table" and table.concat(cmd, " ") or "<function>"),
    "",
    "attached buffers (" .. #bufs .. "):",
  }
  return vim.list_extend(lines, bufs)
end

--- How long to wait for a graceful shutdown before terminating the process
--- Client:stop only schedules a terminate when it is given a number, so with the
--- default exit_timeout of false a server that ignores the shutdown request never
--- exits. Restart then stalls forever, which is what codebook-lsp does.
--- @param client vim.lsp.Client
--- @return integer|boolean
local function exit_timeout(client)
  return client.exit_timeout or 1000
end

--- Restart a single client instance
--- Core's :lsp restart is name-scoped, so it would also restart same-named
--- clients belonging to other projects.
--- @param client vim.lsp.Client
local function restart(client)
  if type(client._restart) == "function" then
    client:_restart(exit_timeout(client))
  else
    vim.cmd("lsp restart " .. client.name)
  end
end

--- @param opts { title: string, verb: string, action: fun(client: vim.lsp.Client) }
local function client_picker(opts)
  local clients = project_clients()
  if #clients == 0 then
    vim.notify("No LSP clients in this project", vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  local items = {}
  for _, client in ipairs(clients) do
    -- snacks deepcopies the picker opts and a client holds a uv handle, so the
    -- item carries the id and resolves the client when it is used
    items[#items + 1] =
      { text = client.name, id = client.id, root = short_root(client, cwd) }
  end

  require("snacks").picker.pick({
    source = "lsp",
    title = opts.title,
    items = items,
    format = function(item)
      local ret = { { item.text, "SnacksPickerLabel" } }
      if item.root ~= "" then
        ret[#ret + 1] = { "  " }
        ret[#ret + 1] = { item.root, "SnacksPickerComment" }
      end
      return ret
    end,
    preview = function(ctx)
      local client = ctx.item and vim.lsp.get_client_by_id(ctx.item.id)
      if not client then
        return
      end
      ctx.preview:reset()
      ctx.preview:set_title(client.name)
      ctx.preview:set_lines(details(client))
      ctx.preview:highlight({ ft = "yaml" })
    end,
    confirm = function(picker)
      local selected = picker:selected({ fallback = true })
      picker:close()
      local names = {}
      for _, item in ipairs(selected) do
        local client = vim.lsp.get_client_by_id(item.id)
        if client then
          opts.action(client)
          names[#names + 1] = client.name
        end
      end
      if #names > 0 then
        vim.notify(
          opts.verb .. " " .. table.concat(names, ", "),
          vim.log.levels.INFO
        )
      end
    end,
  })
end

--- Pick project clients and restart them
function M.restart()
  client_picker({ title = "Restart LSP", verb = "Restarting", action = restart })
end

--- Pick project clients and stop them
function M.stop()
  client_picker({
    title = "Stop LSP",
    verb = "Stopped",
    action = function(client)
      client:stop(exit_timeout(client))
    end,
  })
end

--- Pick a config for this filetype that has no client on the buffer, and enable it
--- vim.lsp.enable re-runs the FileType autocmd, which starts a config that is
--- already enabled but stopped
function M.enable()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  if ft == "" then
    vim.notify("Current buffer has no filetype", vim.log.levels.WARN)
    return
  end

  local attached = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    attached[client.name] = true
  end

  local items = {}
  for _, config in ipairs(vim.lsp.get_configs({ filetype = ft })) do
    if not attached[config.name] then
      items[#items + 1] = {
        text = config.name,
        status = vim.lsp.is_enabled(config.name) and "enabled" or "disabled",
      }
    end
  end
  if #items == 0 then
    vim.notify("Every " .. ft .. " server is attached", vim.log.levels.INFO)
    return
  end

  require("snacks").picker.pick({
    source = "lsp",
    title = "Enable LSP",
    items = items,
    format = function(item)
      return {
        { item.text, "SnacksPickerLabel" },
        { "  " },
        { item.status, "SnacksPickerComment" },
      }
    end,
    confirm = function(picker)
      local selected = picker:selected({ fallback = true })
      picker:close()
      for _, item in ipairs(selected) do
        vim.lsp.enable(item.text)
      end
    end,
  })
end

--- Open the LSP log at the newest entry
function M.log()
  vim.cmd.tabedit(vim.fn.fnameescape(vim.lsp.log.get_filename()))
  vim.cmd("normal! G")
end

return M
