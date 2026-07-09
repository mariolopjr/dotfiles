-- Obsidian integration with id-addressed zettelkasten

--- Obsidian vaults, generated from chezmoi data into util/obsidian_vaults.lua,
--- edit .chezmoidata/obsidian.toml to change them
--- @type { name: string, path: string }[]
local vaults = require("util.obsidian_vaults")

--- Snacks vaults picker
local function pick_vaults()
  local items = {}
  for _, v in ipairs(vaults) do
    items[#items + 1] = { text = v.name, file = v.path }
  end
  Snacks.picker.pick({
    items = items,
    title = "Obsidian Vaults",
    format = "text",
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.schedule(function()
        -- switch into the vault
        vim.cmd.cd(vim.fn.fnameescape(item.file))
        if vim.fn.filereadable(item.file .. "/.session.nvim") == 1 then
          require("mini.sessions").read(".session.nvim")
        else
          Snacks.explorer({ cwd = item.file })
        end
      end)
    end,
  })
end

return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    event = {
      "BufReadPre " .. vaults[1].path .. "/*.md",
      "BufNewFile " .. vaults[1].path .. "/*.md",
    },
    cmd = "Obsidian",
    init = function()
      -- load the picker so the dashboard and keymap can open it
      -- without loading obsidian.nvim
      vim.api.nvim_create_user_command(
        "ObsidianVaults",
        pick_vaults,
        { desc = "Pick an Obsidian vault" }
      )
      vim.keymap.set(
        "n",
        "<leader>so",
        pick_vaults,
        { desc = "[O]bsidian Vaults" }
      )
    end,
    -- stylua: ignore
    keys = {
      -- pickers
      { "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Find note" },
      { "<leader>og", "<cmd>Obsidian search<cr>", desc = "Grep vault" },
      { "<leader>od", "<cmd>Obsidian dailies<cr>", desc = "Daily notes" },
      { "<leader>o#", "<cmd>Obsidian tags<cr>", desc = "Tags" },
      { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
      { "<leader>ol", "<cmd>Obsidian links<cr>", desc = "Links in note" },
      -- create
      { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note" },
      { "<leader>oN", "<cmd>Obsidian new_from_template<cr>", desc = "New note from template" },
      { "<leader>of", function()
          -- pick a vault folder, then create a zettel there via note_id_func
          local root = vaults[1].path
          local skip = {
            [".git"] = true, [".obsidian"] = true, [".claude"] = true,
            ["_templates"] = true, ["_data"] = true,
          }
          local items = { { text = "(vault root)", file = root } }
          local function walk(dir, rel)
            for name, ty in vim.fs.dir(dir) do
              if ty == "directory" and not skip[name] and name:sub(1, 1) ~= "." then
                local abs = dir .. "/" .. name
                local display = rel == "" and name or (rel .. "/" .. name)
                items[#items + 1] = { text = display, file = abs }
                walk(abs, display)
              end
            end
          end
          walk(root, "")
          table.sort(items, function(a, b) return a.text < b.text end)
          Snacks.picker.pick({
            items = items,
            title = "New note: pick folder",
            format = "text",
            confirm = function(picker, item)
              picker:close()
              if not item then return end
              vim.schedule(function()
                local api = require("obsidian.api")
                local title = api.input("Title (optional): ")
                if title == nil then
                  return vim.notify("Aborted", vim.log.levels.WARN)
                end
                title = vim.trim(title)
                local id = title ~= "" and title or nil
                local note = require("obsidian.note").create({
                  id = id,
                  title = id,
                  dir = item.file,
                })
                note:write()
                note:open({ sync = true })
              end)
            end,
          })
        end, desc = "New note in [f]older" },
      { "<leader>oG", function()
          local root = vaults[1].path .. "/projects"
          local items = {}
          for name, ty in vim.fs.dir(root) do
            if ty == "directory" then
              items[#items + 1] = { text = name, file = root .. "/" .. name }
            end
          end
          table.sort(items, function(a, b) return a.text < b.text end)
          Snacks.picker.pick({
            items = items,
            title = "Game concept: pick project",
            format = "text",
            confirm = function(picker, item)
              picker:close()
              if not item then return end
              local file = item.file .. "/game-concept.md"
              local exists = vim.fn.filereadable(file) == 1
              vim.schedule(function()
                vim.cmd.edit(vim.fn.fnameescape(file))
                if exists then
                  vim.notify("game-concept.md already exists, opened it", vim.log.levels.WARN)
                  return
                end
                local tmpl = vaults[1].path .. "/_templates/Game Concept.md"
                vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.readfile(tmpl))
                vim.cmd("normal! gg")
              end)
            end,
          })
        end, desc = "[G]ame concept from template" },
      { "<leader>ot", "<cmd>Obsidian today<cr>", desc = "Today's daily" },
      { "<leader>oy", "<cmd>Obsidian yesterday<cr>", desc = "Yesterday's daily" },
      { "<leader>oT", "<cmd>Obsidian tomorrow<cr>", desc = "Tomorrow's daily" },
      -- edit
      { "<leader>oc", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Toggle checkbox" },
      { "<leader>oi", "<cmd>Obsidian template<cr>", desc = "Insert template" },
      { "<leader>op", "<cmd>Obsidian paste_img<cr>", desc = "Paste image" },
      { "<leader>or", "<cmd>Obsidian rename<cr>", desc = "Rename note (update links)" },
      { "<leader>ox", ":Obsidian extract_note<cr>", mode = "x", desc = "Extract selection to note" },
      { "<leader>ok", ":Obsidian link<cr>", mode = "x", desc = "Link selection to note" },
      { "<leader>oK", ":Obsidian link_new<cr>", mode = "x", desc = "Link selection to new note" },
      -- vault
      { "<leader>oO", "<cmd>Obsidian open<cr>", desc = "Open in Obsidian app" },
    },
    opts = {
      workspaces = vaults,
      legacy_commands = false,

      picker = { name = "snacks.picker" },

      -- only write frontmatter for non-project directories
      frontmatter = {
        enabled = function(fname)
          return (fname or ""):match("^/?projects/") == nil
        end,
        sort = { "id", "aliases", "tags", "created", "updated" },
        func = function(note)
          local util = require("obsidian.util")
          local out = {}
          if note.metadata ~= nil then
            for k, v in pairs(note.metadata) do
              out[k] = v
            end
          end
          out.id = note.id
          out.aliases = (note.aliases and #note.aliases > 0) and note.aliases
            or nil
          out.tags = (note.tags and #note.tags > 0) and note.tags or nil
          if
            out.created == nil
            or out.created == vim.NIL
            or out.created == ""
          then
            out.created = util.format_date(os.time(), "YYYY-MM-DD")
          end
          out.updated = util.format_date(os.time(), "YYYY-MM-DD HH:mm")
          return out
        end,
      },

      -- zettel ids as <unix-timestamp>-<title-slug>, falling back to a random
      -- suffix when there is no title
      -- notes in projects dir use title as filename
      note_id_func = function(title, dir)
        if ("/" .. tostring(dir or "") .. "/"):match("/projects/") then
          return (title and title ~= "") and title
            or require("obsidian.builtin").zettel_id()
        end
        local builtin = require("obsidian.builtin")
        if not title or title == "" then
          return builtin.zettel_id()
        end
        return tostring(os.time()) .. "-" .. builtin.title_to_slug(title)
      end,
      new_notes_location = "current_dir",

      callbacks = {
        create_note = function(note)
          local in_projects = tostring(note.path):match("/projects/") ~= nil
          if note.title and note.title ~= "" and not in_projects then
            note:add_alias(note.title)
          end
        end,
      },

      templates = { folder = "_templates" },

      -- render-markdown draws checkboxes, bullets and links instead
      ui = { enable = false },

      -- plain toggle, the app only knows space and x by default
      checkbox = { order = { " ", "x" } },

      -- gc comments with %% %% obsidian syntax inside notes
      comment = { enabled = true },

      footer = { separator = false },
    },
  },

  -- render the extended obsidian checkbox states
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      checkbox = {
        custom = {
          cancelled = {
            raw = "[~]",
            rendered = "󰰱 ",
            highlight = "RenderMarkdownError",
          },
          important = {
            raw = "[!]",
            rendered = " ",
            highlight = "RenderMarkdownWarn",
          },
          forwarded = {
            raw = "[>]",
            rendered = " ",
            highlight = "RenderMarkdownInfo",
          },
        },
      },
    },
  },
}
