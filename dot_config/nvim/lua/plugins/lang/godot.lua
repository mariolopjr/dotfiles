-- Godot file support
vim.filetype.add({
  extension = {
    gd = "gdscript",
    gdshader = "gdshader",
    tscn = "gdresource",
    tres = "gdresource",
    godot = "gdresource",
    gdextension = "gdresource",
  },
})

-- map the gdresource filetype to the godot_resource parser
vim.treesitter.language.register("godot_resource", "gdresource")

-- serve a per-project pipe so godot-nvim-edit can remote into this instance
-- The pipe is named by a hash of the canonical project path and lives in
-- the cache dir: unix socket paths cap at 104 bytes on macOS, so it cannot
-- live in the project folder
local served = {}

local function serve_project(project)
  if served[project] then
    return
  end
  local cache = (vim.env.XDG_CACHE_HOME or vim.fn.expand("~/.cache"))
    .. "/godot-nvim"
  local pipe = cache .. "/" .. vim.fn.sha256(project):sub(1, 12) .. ".pipe"
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", pipe)
  if ok and chan > 0 then
    -- another instance serves this project, leave served unset so a later
    -- buffer read can claim the pipe if that instance closes
    vim.fn.chanclose(chan)
  else
    vim.fn.mkdir(cache, "p")
    -- a stale socket from a killed instance blocks serverstart
    os.remove(pipe)
    if pcall(vim.fn.serverstart, pipe) then
      served[project] = true
    end
  end
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("godot_nvim_pipe", { clear = true }),
  callback = function(ev)
    local file = vim.api.nvim_buf_get_name(ev.buf)
    if file == "" or vim.bo[ev.buf].buftype ~= "" then
      return
    end
    -- project.godot sits at the project root itself or in a godot/ subdir
    -- of a workspace root
    for dir in vim.fs.parents(file) do
      for _, marker in ipairs({ "/project.godot", "/godot/project.godot" }) do
        local found = vim.uv.fs_realpath(dir .. marker)
        if found then
          serve_project(vim.fs.dirname(found))
          return
        end
      end
    end
  end,
})

return {}
