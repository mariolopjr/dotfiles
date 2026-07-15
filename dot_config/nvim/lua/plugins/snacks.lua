--- Get the root directory using LSP or .git
--- @return string root_dir The root directory
local function get_root_dir()
  --- @type string|nil
  local lsp_root = vim.lsp.buf.list_workspace_folders()[1]
  if lsp_root then
    return lsp_root
  end

  -- fallback to searching for .git directory
  --- @type string|nil
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 and git_root and git_root ~= "" then
    return git_root
  end

  -- fallback to current working directory
  --- @type string
  return vim.fn.getcwd()
end

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      dashboard = {
        enabled = true,
        preset = {
          -- stylua: ignore
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.picker.projects()" },
            { icon = " ", key = "v", desc = "Vaults", action = ":ObsidianVaults" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          {
            icon = " ",
            title = "Keymaps",
            section = "keys",
            indent = 2,
            padding = 1,
          },
          {
            icon = " ",
            title = "Projects",
            section = "projects",
            indent = 2,
            padding = 1,
          },
          {
            icon = " ",
            title = "Recent Files",
            indent = 2,
            padding = 1,
            -- only files opened directly on the command line (nvim file.txt)
            require("util.startup_files").section({ limit = 5 }),
          },
          { section = "startup" },
        },
      },
      explorer = {
        replace_netrw = true,
      },
      gitbrowse = {},
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        sources = {
          explorer = {
            -- hide Godot metadata companions from the explorer tree
            exclude = { "*.uid", "*.import" },
          },
          files = {
            -- hide Godot metadata companions from the file picker
            exclude = { "*.uid", "*.import" },
          },
          grep = {
            -- hide Godot metadata companions from grep results
            exclude = { "*.uid", "*.import" },
          },
          lsp_symbols = {
            -- for ledger files, transactions are Event-kind symbols
            -- so opt ledger out of the default kind filter
            filter = { ledger = true },
          },
          lsp_workspace_symbols = {
            -- for ledger files, transactions are Event-kind symbols
            -- so opt ledger out of the default kind filter
            filter = { ledger = true },
          },
        },
        win = {
          input = {
            keys = {
              ["<Esc>"] = { "close", mode = { "n", "i" } },
              -- alt+h resizes splits everywhere, remap toggling hidden files to
              -- M-.
              ["<a-h>"] = false,
              ["<a-.>"] = { "toggle_hidden", mode = { "i", "n" } },
              -- scroll like lazygit
              ["J"] = { "preview_scroll_down", mode = { "i", "n" } },
              ["K"] = { "preview_scroll_up", mode = { "i", "n" } },
              ["H"] = { "preview_scroll_left", mode = { "i", "n" } },
              ["L"] = { "preview_scroll_right", mode = { "i", "n" } },
            },
          },
          list = {
            keys = {
              -- alt+h resizes splits everywhere, remap toggling hidden files to
              -- M-.
              ["<a-h>"] = false,
              ["<a-.>"] = "toggle_hidden",
            },
          },
        },
      },
      quickfile = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = {
        enabled = true,
        -- the statuscolumn has two sign slots, left ("mark"/"sign") and right
        -- ("fold"/"git"), and shows one sign in each. Diagnostics already own
        -- the left one, so a coverage bar placed there loses the slot to any
        -- line carrying a diagnostic. Using the right slot, which mini.diff
        -- leaves empty since it draws in the number column, means coverage
        -- can use the right column as 'git'
        git = { patterns = { "GitSign", "MiniDiffSign", "Coverage" } },
      },
      terminal = { enabled = false },
      words = { enabled = true },
    },
    -- stylua: ignore
    keys = {
      -- git
      { "<leader>gb", function() Snacks.git.blame_line() end, desc = "[G]it [B]lame" },
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "[G]it [B]rowse" },
      { "<leader>gf", function() Snacks.lazygit.log_file() end, desc = "Lazygit Current File History" },
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<M-g>", function() Snacks.lazygit() end, desc = "Lazygit", mode = { "n", "t" } },
      { "<leader>gl", function() Snacks.lazygit.log() end, desc = "Lazygit Log (cwd)" },
      { "<leader>gc", function() Snacks.picker.git_log() end, desc = "Git Log" },
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
      -- claude cli
      { "<leader>aC", function() require("util.claude").toggle() end, desc = "[C]laude Toggle", mode = { "n", "v" } },
      { "<leader>aQ", function() require("util.claude").quit() end, desc = "Claude [Q]uit" },
      { "<M-c>", function() require("util.claude").toggle() end, desc = "Claude Toggle", mode = { "n", "t" } },
      -- floating shell terminal
      { "<M-t>", function() require("util.terminal").toggle() end, desc = "Terminal Toggle", mode = { "n", "t" } },
      -- zen / zoom, zoom maximizes the current window, zen is distraction free
      { "<leader>z", function() Snacks.zen.zoom() end, desc = "[Z]oom (maximize window)" },
      { "<leader>Z", function() Snacks.zen() end, desc = "[Z]en Mode" },
      -- chezmoi
      { "<leader>pd", function() require("util.chezmoi").diff() end, desc = "Chezmoi [D]iff" },
      { "<leader>pa", function() require("util.chezmoi").apply() end, desc = "Chezmoi [A]pply" },
      { "<leader>pI", function() require("util.chezmoi").init() end, desc = "Chezmoi [I]nit" },
      -- top pickers
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>.", function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
      -- find
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<leader><leader>", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
      -- grep
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
      { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "n", "x" } },
      -- search
      { "<leader>s.", function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
      { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>sd", function() Snacks.picker.diagnostics_buffer() end, desc = "Diagnostics (Buffer)" },
      { "<leader>sD", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>se", function() Snacks.picker.diagnostics_buffer({ severity = vim.diagnostic.severity.ERROR }) end, desc = "Errors (Buffer)" },
      { "<leader>sE", function() Snacks.picker.diagnostics({ severity = vim.diagnostic.severity.ERROR }) end, desc = "Errors (Project)" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
      { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
      { "<leader>sn", function() Snacks.picker.notifications() end, desc = "Notification History" },
      { "<leader>sN", function() Snacks.picker.notifications({ filter = "error" }) end, desc = "Notification History (Errors)" },
      { "<leader>sp", function() Snacks.picker.projects() end, desc = "[S]earch Projects" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
      { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume" },
      { "<leader>pC", function() Snacks.picker.colorschemes() end, desc = "[C]olorschemes" },
      -- LSP
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "[G]oto [D]efinition" },
      { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "[G]oto [R]eferences" },
      { "gI", function() Snacks.picker.lsp_implementations() end, desc = "[G]oto [I]mplementation" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "[G]oto T[y]pe Definition" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "[S]earch [S]ymbols" },
      { "<leader>sS", function() Snacks.picker.lsp_references() end, desc = "[S]earch References" },
      -- file explorer
      {
        "<leader>fe",
        function()
          ---@diagnostic disable-next-line: missing-fields
          Snacks.explorer({ cwd = get_root_dir() })
        end,
        desc = "[F]ile [E]xplorer (root dir)",
      },
      { "<leader>fE", function() Snacks.explorer() end, desc = "[F]ile [󰘶E]xplorer (cwd)" },
      { "<leader>e", "<leader>fe", desc = "[F]ile [E]xplorer (root dir)", remap = true },
      { "<leader>E", "<leader>fE", desc = "[F]ile [󰘶E]xplorer (cwd)", remap = true },
    },
    config = function(_, opts)
      require("snacks").setup(opts)

      -- persist command-line file arguments
      if vim.v.vim_did_enter == 1 then
        require("util.startup_files").record()
      else
        vim.api.nvim_create_autocmd("VimEnter", {
          once = true,
          callback = function()
            require("util.startup_files").record()
          end,
        })
      end

      -- fancy LSP progress in the notifier
      local progress = vim.defaulttable()
      vim.api.nvim_create_autocmd("LspProgress", {
        ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: "begin" | "report" | "end"}]]
          if not client or type(value) ~= "table" then
            return
          end
          local p = progress[client.id]

          for i = 1, #p + 1 do
            if i == #p + 1 or p[i].token == ev.data.params.token then
              p[i] = {
                token = ev.data.params.token,
                msg = ("[%3d%%] %s%s"):format(
                  value.kind == "end" and 100 or value.percentage or 100,
                  value.title or "",
                  value.message and (" **%s**"):format(value.message) or ""
                ),
                done = value.kind == "end",
              }
              break
            end
          end

          local msg = {} ---@type string[]
          progress[client.id] = vim.tbl_filter(function(v)
            return table.insert(msg, v.msg) or not v.done
          end, p)

          local spinner = {
            "⠋",
            "⠙",
            "⠹",
            "⠸",
            "⠼",
            "⠴",
            "⠦",
            "⠧",
            "⠇",
            "⠏",
          }
          vim.notify(table.concat(msg, "\n"), "info", {
            id = "lsp_progress",
            title = client.name,
            opts = function(notif)
              notif.icon = #progress[client.id] == 0 and " "
                ---@diagnostic disable-next-line: undefined-field
                or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
            end,
          })
        end,
      })
    end,
  },
}
