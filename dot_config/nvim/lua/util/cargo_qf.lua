--- util.cargo_qf: run cargo check or clippy and load its diagnostics into the
--- quickfix list. rust-analyzer's flyCheck is scoped to open files, this catches
--- a whole-workspace clippy run or a link error. Async through vim.system and
--- parses cargo's --message-format=json

local M = {}

--- @param level string? rustc diagnostic level
--- @return string quickfix type
local function qf_type(level)
  if level == "warning" then
    return "W"
  elseif level == "note" or level == "help" then
    return "N"
  end
  return "E"
end

--- @param spans table[]? rustc message spans
--- @return table? the primary span, else the first
local function primary_span(spans)
  spans = spans or {}
  for _, s in ipairs(spans) do
    if s.is_primary then
      return s
    end
  end
  return spans[1]
end

--- @param root string workspace root
--- @param file string span file_name, workspace-relative or absolute
--- @return string absolute path
local function abspath(root, file)
  if file:sub(1, 1) == "/" then
    return file
  end
  return root .. "/" .. file
end

--- @param root string
--- @param stdout string
--- @return table[] quickfix items
local function parse(root, stdout)
  local items, seen = {}, {}
  for line in stdout:gmatch("[^\n]+") do
    local ok, msg = pcall(vim.json.decode, line)
    if ok and msg.reason == "compiler-message" and msg.message then
      local d = msg.message
      local span = primary_span(d.spans)
      if span and span.file_name and span.line_start then
        local file = abspath(root, span.file_name)
        -- --all-targets recompiles shared files per target, dedup repeats
        local key = table.concat({
          file,
          span.line_start,
          span.column_start or 0,
          d.message or "",
        }, "\0")
        if not seen[key] then
          seen[key] = true
          items[#items + 1] = {
            filename = file,
            lnum = span.line_start,
            col = span.column_start or 1,
            text = d.message or "",
            type = qf_type(d.level),
          }
        end
      end
    end
  end
  return items
end

--- Run `cargo <sub>` over the workspace and open the quickfix list on the result
--- @param sub "clippy"|"check"
function M.run(sub)
  local root = vim.fs.root(0, { "Cargo.toml", ".git" }) or vim.fn.getcwd()
  vim.notify("cargo " .. sub .. ": running...")
  vim.system({
    "cargo",
    sub,
    "--workspace",
    "--all-targets",
    "--message-format=json",
  }, { cwd = root, text = true }, function(res)
    local items = parse(root, res.stdout or "")
    vim.schedule(function()
      vim.fn.setqflist({}, " ", { title = "cargo " .. sub, items = items })
      if #items > 0 then
        vim.cmd("copen")
        vim.notify(
          string.format(
            "cargo %s: %d item%s",
            sub,
            #items,
            #items == 1 and "" or "s"
          )
        )
      elseif res.code == 0 then
        vim.notify("cargo " .. sub .. ": clean")
      else
        -- non-zero with nothing parsed means cargo itself failed, surface why
        local err = (res.stderr or ""):match("[^\n]+") or "failed"
        vim.notify("cargo " .. sub .. ": " .. err, vim.log.levels.ERROR)
      end
    end)
  end)
end

local installed = false

function M.setup()
  if installed then
    return
  end
  installed = true
  vim.api.nvim_create_user_command("CargoClippy", function()
    M.run("clippy")
  end, { desc = "cargo clippy into the quickfix list" })
  vim.api.nvim_create_user_command("CargoCheck", function()
    M.run("check")
  end, { desc = "cargo check into the quickfix list" })
end

return M
