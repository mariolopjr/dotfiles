--- profile: navigate profiler output
---
--- :ProfileCpu / :ProfileHeap  load that profile and pick a hotspot
--- :ProfileLoad [path]         load an explicit artifact, autodetected if omitted
--- :ProfileHotspots            re-pick from the last loaded profile
--- :ProfileGutter              toggle inline annotations for every loaded source
--- :ProfileClear               drop all loaded profiles
--- :ProfileSamply / :ProfileDhat  open that profile in its own external viewer
--- :ProfileTracy               launch the tracy gui for the real running game
--- :ProfileBench               pick a criterion benchmark and jump to it

local dhat = require("profile.dhat")
local gutter = require("profile.gutter")
local picker = require("profile.picker")
local resolve = require("profile.resolve")
local samply = require("profile.samply")

local M = {}

--- kind -> { list, title, path }, so cpu and heap coexist
local state = { sources = {}, last = nil }
local installed = false

--- heat colors track diagnostic severities so they follow the colorscheme
local function apply_highlights()
  local set = function(g, o)
    vim.api.nvim_set_hl(0, g, o)
  end
  set("ProfileHeatLow", { link = "DiagnosticHint", default = true })
  set("ProfileHeatMid", { link = "DiagnosticWarn", default = true })
  set("ProfileHeatHigh", { link = "DiagnosticError", default = true })
  set("ProfileGutterTag", { link = "Comment", default = true })
  set("ProfileGutterDelim", { link = "NonText", default = true })
end

--- @param path string
--- @return table? data, string? err
local function decode_maybe_gz(path)
  local fd = io.open(path, "rb")
  if not fd then
    return nil, "cannot read " .. path
  end
  local bytes = fd:read("*a")
  fd:close()
  if bytes:sub(1, 2) == "\31\139" then -- gzip magic
    local res = vim.system({ "gzip", "-dc", path }, { text = true }):wait()
    if res.code ~= 0 then
      return nil, "gunzip failed for " .. path
    end
    bytes = res.stdout or ""
  end
  local ok, data = pcall(vim.json.decode, bytes)
  if not ok then
    return nil, "invalid json in " .. path
  end
  return data
end

--- the samply sidecar sits next to the profile with .syms.json in place of .gz
--- @param path string
--- @return string
local function sidecar_path(path)
  return (path:gsub("%.gz$", "")) .. ".syms.json"
end

--- artifact filenames each kind of profiler writes
local ARTIFACTS = {
  heap = { "dhat-heap.json" },
  cpu = { "cpu-profile.json.gz", "cpu-profile.json", "profile.json.gz" },
}

--- @param names string[]
--- @return string?
local function find_named(names)
  for _, name in ipairs(names) do
    local found = vim.fs.find(name, {
      upward = true,
      path = vim.fn.getcwd(),
      type = "file",
      limit = 1,
    })
    if found[1] then
      return found[1]
    end
  end
  return nil
end

--- @return string?
local function find_artifact()
  local all = {}
  vim.list_extend(all, ARTIFACTS.heap)
  vim.list_extend(all, ARTIFACTS.cpu)
  return find_named(all)
end

--- Load a profile, keeping any other already loaded source. Returns its kind
--- @param path string?
--- @return string? kind
function M.load(path)
  path = path and vim.fn.expand(path) or find_artifact()
  if not path then
    vim.notify(
      "profile: no artifact found, pass a path to :ProfileLoad",
      vim.log.levels.WARN
    )
    return nil
  end
  local data, err = decode_maybe_gz(path)
  if not data then
    vim.notify("profile: " .. err, vim.log.levels.ERROR)
    return nil
  end

  local json_dir = vim.fs.dirname(vim.fn.fnamemodify(path, ":p"))
  local resolver = resolve.make(json_dir)
  local kind, list, title

  if dhat.matches(data) then
    kind, list, title =
      "heap", dhat.hotspots(data, resolver), "Allocation hotspots"
  elseif samply.matches(data) then
    local syms, serr = decode_maybe_gz(sidecar_path(path))
    if not syms then
      vim.notify(
        "profile: samply profile needs its .syms.json sidecar ("
          .. serr
          .. "), record with --unstable-presymbolicate",
        vim.log.levels.ERROR
      )
      return nil
    end
    local root = vim.fs.root(json_dir, ".git") or json_dir
    kind, list, title =
      "cpu", samply.hotspots(data, syms, resolver, root), "CPU hotspots"
  else
    vim.notify(
      "profile: unrecognized artifact, expected a dhat or samply profile",
      vim.log.levels.ERROR
    )
    return nil
  end

  state.sources[kind] = { list = list, title = title, path = path }
  state.last = kind
  gutter.set_source(kind, list)
  vim.notify(
    string.format(
      "profile: %d %s from %s",
      #list,
      title:lower(),
      vim.fn.fnamemodify(path, ":~:.")
    )
  )
  return kind
end

--- @return boolean have_data
local function ensure_loaded()
  if next(state.sources) then
    return true
  end
  return M.load() ~= nil
end

--- Load a specific kind of profile then open its picker, so cpu and heap each
--- get to their own hotspots directly instead of racing the autodetect
--- @param kind "cpu"|"heap"
function M.pick_kind(kind)
  local path = find_named(ARTIFACTS[kind] or {})
  if not path then
    vim.notify(
      "profile: no " .. kind .. " profile found nearby, run the profiler first",
      vim.log.levels.WARN
    )
    return
  end
  local loaded = M.load(path)
  local src = loaded and state.sources[loaded]
  if src then
    picker.open(src.list, src.title)
  end
end

function M.hotspots()
  if not ensure_loaded() then
    return
  end
  local src = state.last and state.sources[state.last]
  if src then
    picker.open(src.list, src.title)
  end
end

function M.toggle_gutter()
  if not ensure_loaded() then
    return
  end
  local on = gutter.toggle()
  vim.notify("profile: gutter " .. (on and "on" or "off"))
end

function M.clear()
  state.sources, state.last = {}, nil
  gutter.clear()
  vim.notify("profile: cleared")
end

--- Open the cpu profile in the samply web ui
function M.samply_open()
  if vim.fn.executable("samply") == 0 then
    vim.notify(
      "profile: samply not found, install it with brew or cargo",
      vim.log.levels.ERROR
    )
    return
  end
  local path = find_named(ARTIFACTS.cpu)
  if not path then
    vim.notify(
      "profile: no cpu profile found nearby, run the profiler first",
      vim.log.levels.WARN
    )
    return
  end
  local root = vim.fs.root(path, ".git") or vim.fn.getcwd()
  vim.fn.jobstart({ "samply", "load", path }, { cwd = root, detach = true })
  vim.notify(
    "profile: samply load "
      .. vim.fn.fnamemodify(path, ":~:.")
      .. ", leaves a local server running"
  )
end

--- Open the dhat heap viewer in the browser. The viewer has no url parameter to
--- preload a file, so copy the json path to the clipboard for its Load dialog
function M.dhat_open()
  local path = find_named(ARTIFACTS.heap)
  if not path then
    vim.notify(
      "profile: no heap profile found nearby, run the profiler first",
      vim.log.levels.WARN
    )
    return
  end
  vim.fn.setreg("+", vim.fn.fnamemodify(path, ":p"))
  vim.ui.open("https://nnethercote.github.io/dh_view/dh_view.html")
  vim.notify(
    "profile: heap json path copied, click Load in the viewer and paste"
  )
end

--- Launch the tracy gui. It waits for the running game to connect
function M.tracy_open()
  if vim.fn.executable("tracy-profiler") == 0 then
    vim.notify(
      "profile: tracy-profiler not found, brew install tracy",
      vim.log.levels.ERROR
    )
    return
  end
  vim.fn.jobstart({ "tracy-profiler" }, { detach = true })
  vim.notify(
    "profile: launched tracy-profiler, feed it with `just profile-tracy`"
  )
end

--- Pick a criterion benchmark by mean time and jump to its bench function
function M.bench()
  local crit = require("profile.criterion")
  local dir = crit.find_dir()
  if not dir then
    vim.notify(
      "profile: no target/criterion found, run `just bench` first",
      vim.log.levels.WARN
    )
    return
  end
  -- <root>/target/criterion -> <root>, where the bench sources live
  local root = vim.fs.dirname(vim.fs.dirname(dir))
  picker.open(crit.hotspots(dir, root), "Benchmark timings")
end

function M.setup()
  if installed then
    return
  end
  installed = true

  apply_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("profile-highlights", { clear = true }),
    callback = apply_highlights,
  })

  vim.api.nvim_create_user_command("ProfileCpu", function()
    M.pick_kind("cpu")
  end, { desc = "Load the cpu profile and pick a hotspot" })

  vim.api.nvim_create_user_command("ProfileHeap", function()
    M.pick_kind("heap")
  end, { desc = "Load the heap profile and pick a hotspot" })

  vim.api.nvim_create_user_command(
    "ProfileLoad",
    function(o)
      M.load(o.args ~= "" and o.args or nil)
    end,
    { nargs = "?", complete = "file", desc = "Load a dhat or samply profile" }
  )

  vim.api.nvim_create_user_command("ProfileHotspots", function()
    M.hotspots()
  end, { desc = "Re-pick a hotspot from the loaded profile" })

  vim.api.nvim_create_user_command("ProfileGutter", function()
    M.toggle_gutter()
  end, { desc = "Toggle inline profile annotations" })

  vim.api.nvim_create_user_command("ProfileClear", function()
    M.clear()
  end, { desc = "Drop all loaded profiles" })

  vim.api.nvim_create_user_command("ProfileSamply", function()
    M.samply_open()
  end, { desc = "Open the cpu profile in the samply web ui" })

  vim.api.nvim_create_user_command("ProfileDhat", function()
    M.dhat_open()
  end, { desc = "Open the dhat heap viewer in the browser" })

  vim.api.nvim_create_user_command("ProfileTracy", function()
    M.tracy_open()
  end, { desc = "Launch the tracy gui" })

  vim.api.nvim_create_user_command("ProfileBench", function()
    M.bench()
  end, { desc = "Pick a criterion benchmark hotspot" })

  local map = vim.keymap.set
  map("n", "<leader>Pc", function()
    M.pick_kind("cpu")
  end, { desc = "Profile: [C]PU hotspots" })
  map("n", "<leader>Ph", function()
    M.pick_kind("heap")
  end, { desc = "Profile: [H]eap hotspots" })
  map("n", "<leader>Pg", function()
    M.toggle_gutter()
  end, { desc = "Profile: toggle [G]utter" })
  map("n", "<leader>Pl", function()
    M.load()
  end, { desc = "Profile: [L]oad a path" })
  map("n", "<leader>Px", function()
    M.clear()
  end, { desc = "Profile: clear [X] all" })
  map("n", "<leader>Po", function()
    M.samply_open()
  end, { desc = "Profile: [O]pen samply in browser" })
  map("n", "<leader>Pd", function()
    M.dhat_open()
  end, { desc = "Profile: [D]hat viewer in browser" })
  map("n", "<leader>Pt", function()
    M.tracy_open()
  end, { desc = "Profile: open [T]racy" })
  map("n", "<leader>Pb", function()
    M.bench()
  end, { desc = "Profile: [B]enchmarks" })
end

return M
