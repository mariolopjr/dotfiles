-- neotest's config and run argument types mark every field required, while the
-- API takes partial tables
---@diagnostic disable: missing-fields

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",

      -- .NET
      {
        "Nsidorenco/neotest-vstest",
        init = function()
          vim.g.neotest_vstest = {
            -- dap.lua registers netcoredbg under the name coreclr, and the
            -- adapter's own default of "netcoredbg" resolves to no adapter
            dap_settings = { type = "coreclr" },
          }
        end,
      },

      -- Go
      {
        "fredrikaverpil/neotest-golang",
        dependencies = { "leoluz/nvim-dap-go" },
      },
    },
    init = function()
      -- neotest discovers lazily, so perform async test discovery after LSP is
      -- initialized
      local servers = {
        gopls = true,
        roslyn = true,
        roslyn_ls = true,
        rust_analyzer = true,
      }
      local warmed = {}
      local timers = {}

      --- @param client vim.lsp.Client?
      local function warm(client)
        if not client or not servers[client.name] then
          return
        end

        local root = client.root_dir or vim.uv.cwd()
        if not root or warmed[root] then
          return
        end
        warmed[root] = true

        -- the first require of neotest is what loads it
        require("util.test").warm()
      end

      local group =
        vim.api.nvim_create_augroup("neotest-warm", { clear = true })

      vim.api.nvim_create_autocmd("LspProgress", {
        group = group,
        pattern = "end",
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or not servers[client.name] then
            return
          end

          local root = client.root_dir or vim.uv.cwd()
          if not root or warmed[root] then
            return
          end

          if timers[root] then
            timers[root]:stop()
          end
          timers[root] = vim.defer_fn(function()
            warm(client)
          end, 3000)
        end,
      })

      -- a server that reports no progress at all still gets warmed, just later
      vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          vim.defer_fn(function()
            warm(client)
          end, 30000)
        end,
      })
    end,
    config = function()
      -- compact multiline test failure messages into one line
      local neotest_ns = vim.api.nvim_create_namespace("neotest")
      vim.diagnostic.config({
        virtual_text = {
          format = function(diagnostic)
            -- bound to a local, returning the chain directly would also return
            -- gsub's replacement count
            local message = diagnostic.message
              :gsub("\n", " ")
              :gsub("\t", " ")
              :gsub("%s+", " ")
              :gsub("^%s+", "")
            return message
          end,
        },
      }, neotest_ns)

      -- neotest-vstest falls back to the git root when it finds no solution, so
      -- it claims every project, Go ones included
      -- Only let neotest load tests in directories that actually have a .NET project
      local vstest = require("neotest-vstest")
      local vstest_root = vstest.root
      vstest.root = function(path)
        local dotnet = require("neotest.lib").files.match_root_pattern(
          "*.sln",
          "*.slnx",
          "*.csproj",
          "*.fsproj"
        )(path)
        return dotnet and vstest_root(path) or nil
      end

      local adapters = {
        vstest,
        require("neotest-golang")({}),
      }

      -- rustaceanvim carries its own adapter
      local ok, rust = pcall(require, "rustaceanvim.neotest")
      if ok then
        table.insert(adapters, rust)
      end

      -- display neotest summary in floating window
      local function summary_window()
        local width = math.min(math.floor(vim.o.columns * 0.5), 80)
        local height = math.floor(vim.o.lines * 0.8)

        -- neotest swaps its own buffer in
        local buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].bufhidden = "wipe"

        -- entered on purpose. neotest saves the current window before calling
        -- this and restores it itself unless it was asked to enter
        return vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = width,
          height = height,
          row = math.floor((vim.o.lines - height) / 2) - 1,
          col = math.floor((vim.o.columns - width) / 2),
          style = "minimal",
          border = "rounded",
          title = " Tests ",
          title_pos = "center",
        })
      end

      vim.api.nvim_create_autocmd("FileType", {
        desc = "Summary keys neotest does not bind itself",
        group = vim.api.nvim_create_augroup(
          "neotest-summary",
          { clear = true }
        ),
        pattern = "neotest-summary",
        callback = function(ev)
          vim.keymap.set("n", "q", function()
            require("neotest").summary.close()
          end, { buffer = ev.buf, desc = "Close the summary" })

          vim.keymap.set("n", "E", function()
            require("util.test").expand_summary()
          end, { buffer = ev.buf, desc = "Expand the whole tree" })
        end,
      })

      require("neotest").setup({
        adapters = adapters,
        status = { virtual_text = true },
        output = { open_on_run = true },
        summary = { open = summary_window },
        quickfix = {
          open = function()
            vim.cmd("copen")
          end,
        },
      })
    end,
    -- stylua: ignore
    keys = {
      { "<leader>Tp", function() require("util.test").pick_tests() end, desc = "[P]ick a Test" },
      { "<leader>TP", function() require("util.test").pick_scopes() end, desc = "[󰘶P]ick a Test Scope" },
      { "<leader>Tr", function() require("neotest").run.run() end, desc = "[R]un Nearest" },
      { "<leader>TR", function() require("util.test").refresh() end, desc = "[󰘶R]escan for New Tests" },
      { "<leader>Td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "[D]ebug Nearest" },
      { "<leader>Tt", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File" },
      { "<leader>TT", function() require("util.test").run_all() end, desc = "Run All 󰘶Tests" },
      { "<leader>Tl", function() require("neotest").run.run_last() end, desc = "Run [L]ast" },
      -- enter it, a float you are not in cannot be dismissed with q. E expands the tree
      { "<leader>Ts", function() require("neotest").summary.toggle({ enter = true }) end, desc = "Toggle [S]ummary" },
      { "<leader>To", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show [O]utput" },
      { "<leader>TO", function() require("neotest").output_panel.toggle() end, desc = "Toggle 󰘶Output Panel" },
      { "<leader>TS", function() require("neotest").run.stop() end, desc = "[󰘶S]top" },
      { "<leader>Tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Toggle [W]atch" },
    },
  },
}
