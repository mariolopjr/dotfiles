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
        if warmed[root] then
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
          if warmed[root] then
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
            return diagnostic.message
              :gsub("\n", " ")
              :gsub("\t", " ")
              :gsub("%s+", " ")
              :gsub("^%s+", "")
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

      require("neotest").setup({
        adapters = adapters,
        status = { virtual_text = true },
        output = { open_on_run = true },
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
      { "<leader>Ts", function() require("neotest").summary.toggle() end, desc = "Toggle [S]ummary" },
      { "<leader>To", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show [O]utput" },
      { "<leader>TO", function() require("neotest").output_panel.toggle() end, desc = "Toggle 󰘶Output Panel" },
      { "<leader>TS", function() require("neotest").run.stop() end, desc = "[󰘶S]top" },
      { "<leader>Tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Toggle [W]atch" },
    },
  },
}
