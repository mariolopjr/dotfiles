---@param config {type?:string, args?:string[]|fun():string[]?}
local function get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or
      config.args or {} --[[@as string[] | string ]]
  local args_str = type(args) == "table" and table.concat(args, " ") or
      args --[[@as string]]

  config = vim.deepcopy(config)
  ---@cast args string[]
  config.args = function()
    local new_args = vim.fn.expand(vim.fn.input("Run with args: ", args_str)) --[[@as string]]
    if config.type and config.type == "java" then
      ---@diagnostic disable-next-line: return-type-mismatch
      return new_args
    end
    return require("dap.utils").splitstr(new_args)
  end
  return config
end

return {
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    "folke/lazydev.nvim",
    ft = "lua",
    enabled = not vim.g.vscode,
    opts = {
      library = {
        { plugins = { "nvim-dap-ui" }, types = true },
      },
    },
  },

  -- install debuggers and linters, etc.
  {
    "williamboman/mason.nvim",
    enabled = not vim.g.vscode,
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {
        "codelldb",
        "stylua",
        "shfmt",
        "fixjson",
        "isort",
        "prettier",
        "xmlformatter",
      },
    },
    ---@param opts MasonSettings | {ensure_installed: string[]}
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          -- trigger FileType event to possibly load this newly installed LSP server
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)

      mr.refresh(function()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          if not p:is_installed() then
            p:install()
          end
        end
      end)
    end,
    keys = { { "<leader>pm", "<cmd>Mason<cr>", desc = "[P]lugin [M]ason" } },
  },

  -- lsp integration with mason
  {
    "williamboman/mason-lspconfig.nvim",
    enabled = not vim.g.vscode,
    opts = {
      ensure_installed = {
        "bashls",
        "clangd",
        "gopls",
        "lua_ls",
        "marksman",
        "pyright",
        "ruff",
      },
    },
  },

  -- rust support
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = "rust",
    enabled = not vim.g.vscode,
    opts = {
      server = {
        on_attach = function(_, bufnr)
          vim.keymap.set("n", "<leader>ca", function()
            vim.cmd.RustLsp("codeAction")
          end, { desc = "[C]ode [A]ction", buffer = bufnr })
          vim.keymap.set("n", "K", function()
            vim.cmd.RustLsp({ "hover", "actions" })
          end, { desc = "[K] Hover", buffer = bufnr })
          vim.keymap.set("n", "gR", function()
            vim.cmd.RustLsp({ "hover", "range" })
          end, { desc = "[G] Hover [R]ange", buffer = bufnr })
          vim.keymap.set("n", "<leader>dd", function()
            vim.cmd.RustLsp("debuggables")
          end, { desc = "[D]ebug Rust [D]ebuggables", buffer = bufnr })
        end,
      },
      default_settings = {
        -- rust-analyzer language server configuration
        ["rust-analyzer"] = {
          cargo = {
            allFeatures = true,
            loadOutDirsFromCheck = true,
            buildScripts = {
              enable = true,
            },
          },
          rustfmt = {
            extraArgs = { "--unstable-features" },
          },
          -- clippy lints
          checkOnSave = true,
          -- diagnostics
          diagnostics = {
            enable = true,
          },
          procMacro = {
            enable = true,
            ignored = {
              ["async-trait"] = { "async_trait" },
              ["napi-derive"] = { "napi" },
              ["async-recursion"] = { "async_recursion" },
            },
          },
          files = {
            excludeDirs = {
              ".direnv",
              ".git",
              ".github",
              ".gitlab",
              "bin",
              "node_modules",
              "target",
              "venv",
              ".venv",
            },
          },
        },
      },
    },
    config = function(_, opts)
      local package_path = require("mason-registry").get_package("codelldb")
          :get_install_path()
      local codelldb = package_path .. "/extension/adapter/codelldb"
      local library_path = package_path .. "/extension/lldb/lib/liblldb.dylib"

      -- ensure linux .so is loaded instead
      local uname = io.popen("uname"):read("*l")
      if uname == "Linux" then
        library_path = package_path .. "/extension/lldb/lib/liblldb.so"
      end

      opts.dap = {
        adapter = require("rustaceanvim.config").get_codelldb_adapter(codelldb,
          library_path),
      }
      vim.g.rustaceanvim = vim.tbl_deep_extend("keep", vim.g.rustaceanvim or {},
        opts or {})

      if vim.fn.executable("rust-analyzer") == 0 then
        vim.notify(
          "**rust-analyzer** not found in PATH, please install it.\nhttps://rust-analyzer.github.io/",
          vim.log.levels.ERROR
        )
      end
    end,
  },

  -- Cargo.toml lsp
  {
    "Saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    enabled = not vim.g.vscode,
    opts = {
      completion = {
        crates = {
          enabled = true,
        },
      },
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
  },

  -- main LSP configuration
  {
    "neovim/nvim-lspconfig",
    event = "LazyFile",
    enabled = not vim.g.vscode,
    dependencies = {
      "saghen/blink.cmp",
    },
    opts = {
      -- LSP Server Settings
      ---@type lspconfig.options
      servers = {
        rust_analyzer = { enabled = false },
      },
    },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func,
              { buffer = event.buf, desc = "LSP: " .. desc })
          end

          map("K", vim.lsp.buf.hover, "Hover")
          map("gK", vim.lsp.buf.signature_help, "Signature Help")
          map("<leader>cr", vim.lsp.buf.rename, "[C]ode [R]ename")
          map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction",
            { "n", "x" })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if
              client
              and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight)
          then
            local highlight_augroup =
                vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({
                  group = "lsp-highlight",
                  buffer = event2.buf,
                })
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map("<leader>ch", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({
                bufnr =
                    event.buf
              }))
            end, "[C]ode Toggle Inlay [H]ints")
          end
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities =
          vim.tbl_deep_extend("force", capabilities,
            require("blink.cmp").get_lsp_capabilities())

      -- enable language servers
      local lspconfig = require("lspconfig")

      lspconfig.bashls.setup({
        capabilities = capabilities,
      })
      lspconfig.clangd.setup({
        -- cmd = { "clangd", "--compile-commands-dir=." },
        filetypes = { "c", "cpp", "objc", "objcpp" },
        root_dir = require("lspconfig").util.root_pattern(
          "compile_commands.json", ".git"),
        settings = {
          clangd = {
            compilationDatabasePath = ".",
          },
        },
        capabilities = capabilities,
      })
      lspconfig.fish_lsp.setup({
        capabilities = capabilities,
      })
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            completion = {
              callSnippet = "Replace",
            },
            telemetry = {
              enable = false,
            },
            -- diagnostics = { disable = { 'missing-fields' } },
          },
        },
      })
      lspconfig.pyright.setup({
        capabilities = capabilities,
      })
      lspconfig.gopls.setup({
        capabilities = capabilities,
      })
      lspconfig.gdscript.setup({
        name = "godot",
        cmd = vim.lsp.rpc.connect("127.0.0.1", 6005),
      })
    end,
  },

  -- blink completions
  {
    "saghen/blink.cmp",
    dependencies = {
      "xzbdmw/colorful-menu.nvim",
    },
    enabled = not vim.g.vscode,
    version = "*",
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = { preset = "default" },
      appearance = {
        nerd_font_variant = "mono",
      },
      signature = { enabled = true },
      sources = {
        default = { "lazydev", "lsp", "path", "buffer" },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            -- make lazydev completions top priority (see `:h blink.cmp`)
            score_offset = 100,
          },
        },
      },

      -- add colorful-menu to blink
      completion = {
        -- Show documentation when selecting a completion item
        documentation = { auto_show = true, auto_show_delay_ms = 500 },

        menu = {
          draw = {
            columns = { { "kind_icon" }, { "label", gap = 1 } },
            components = {
              label = {
                width = { fill = true, max = 60 },
                text = function(ctx)
                  local highlights_info = require("colorful-menu")
                      .blink_highlights(ctx)
                  if highlights_info ~= nil then
                    return highlights_info.label
                  else
                    return ctx.label
                  end
                end,
                highlight = function(ctx)
                  local highlights = {}
                  local highlights_info = require("colorful-menu")
                      .blink_highlights(ctx)
                  if highlights_info ~= nil then
                    highlights = highlights_info.highlights
                  end
                  for _, idx in ipairs(ctx.label_matched_indices) do
                    table.insert(highlights,
                      { idx, idx + 1, group = "BlinkCmpLabelMatch" })
                  end
                  return highlights
                end,
              },
            },
          },
        },
      },
    },
    opts_extend = { "sources.default" },
  },

  -- setup dap with lsp
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      -- virtual text for the debugger
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {},
      },
      "nvim-neotest/nvim-nio",
    },
    enabled = not vim.g.vscode,
    -- stylua: ignore
    keys = {
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input(
            'Breakpoint condition: '))
        end,
        desc = "[D]ebug [󰘶B]reakpoint Condition"
      },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "[D]ebug Toggle [B]reakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Run/Continue" },
      { "<leader>da", function() require("dap").continue({ before = get_args }) end, desc = "Run with Args" },
      { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to 󰘶Cursor" },
      { "<leader>dg", function() require("dap").goto_() end, desc = "Go to Line (No Execute)" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>dj", function() require("dap").down() end, desc = "Down" },
      { "<leader>dk", function() require("dap").up() end, desc = "Up" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Run Last" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step 󰘶Out" },
      { "<leader>dP", function() require("dap").pause() end, desc = "󰘶Pause" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>ds", function() require("dap").session() end, desc = "Session" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
    },
    config = function()
      require("mason-nvim-dap").setup()

      -- change breakpoint icons
      vim.api.nvim_set_hl(0, "DapStoppedLine",
        { default = true, link = "Visual" })
      local breakpoint_icons = vim.g.have_nerd_font
          and {
            Breakpoint = "",
            BreakpointCondition = "",
            BreakpointRejected = "",
            LogPoint = "",
            Stopped = "",
          }
          or {
            Breakpoint = "●",
            BreakpointCondition = "⊜",
            BreakpointRejected = "⊘",
            LogPoint = "◆",
            Stopped = "⭔",
          }
      for type, icon in pairs(breakpoint_icons) do
        local tp = "Dap" .. type
        local hl = (type == "Stopped") and "DapStop" or "DapBreak"
        vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
      end
    end,
  },

  -- fancy UI for the debugger
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" },
    enabled = not vim.g.vscode,
    -- stylua: ignore
    keys = {
      { "<leader>du", function() require("dapui").toggle({}) end, desc = "Dap UI" },
      { "<leader>de", function() require("dapui").eval() end,     desc = "Eval",  mode = { "n", "v" } },
    },
    opts = {},
    config = function(_, opts)
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close({})
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close({})
      end
    end,
  },

  -- mason.nvim integration
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = "mason.nvim",
    enabled = not vim.g.vscode,
    cmd = { "DapInstall", "DapUninstall" },
  },
}
