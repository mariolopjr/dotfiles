return {
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = "luvit-meta/library", words = { "vim%.uv" } },
        { plugins = { "nvim-dap-ui" }, types = true },
      },
    },
  },
  { "Bilal2453/luvit-meta", lazy = true },
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    lazy = false,
    config = function()
      require("rustaceanvim").server = {
        settings = {
          ["rust-analyzer"] = {
            rustfmt = {
              extraArgs = { "--unstable-features" },
            },
          },
        },
      }
    end,
  },
  {
    -- main LSP configuration
    "neovim/nvim-lspconfig",
    dependencies = {
      { "williamboman/mason.nvim", config = true }, -- must be loaded before dependants
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",

      { "j-hui/fidget.nvim", opts = {} }, -- Useful status updates for LSP.
      -- "hrsh7th/cmp-nvim-lsp",
      "saghen/blink.cmp",

      -- setup dap with lsp
      {
        "mfussenegger/nvim-dap",
        dependencies = {
          "rcarriga/nvim-dap-ui",
          "nvim-neotest/nvim-nio",
          "jay-babu/mason-nvim-dap.nvim",
        },
        config = function()
          local dap = require("dap")
          local dapui = require("dapui")

          -- Dap UI setup
          -- For more information, see |:help nvim-dap-ui|
          dapui.setup()

          -- Change breakpoint icons
          -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
          -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
          -- local breakpoint_icons = vim.g.have_nerd_font
          --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
          --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
          -- for type, icon in pairs(breakpoint_icons) do
          --   local tp = 'Dap' .. type
          --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
          --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
          -- end

          dap.listeners.after.event_initialized["dapui_config"] = dapui.open
          dap.listeners.before.event_terminated["dapui_config"] = dapui.close
          dap.listeners.before.event_exited["dapui_config"] = dapui.close
        end,
      },
    },
    opts = {
      setup = {
        rust_analyzer = function()
          return true
        end,
      },
    },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          -- Jump to the definition of the word under your cursor.
          --  To jump back, press <C-t>.
          map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")

          -- Find references for the word under your cursor.
          map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")

          -- Jump to the implementation of the word under your cursor.
          map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

          -- Jump to the type of the word under your cursor.
          --  the definition of its *type*, not where it was *defined*.
          map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")

          -- Fuzzy find all the symbols in your current document.
          map(
            "<leader>ds",
            require("telescope.builtin").lsp_document_symbols,
            "[D]ocument [S]ymbols"
          )

          -- Fuzzy find all the symbols in your current workspace.
          map(
            "<leader>ws",
            require("telescope.builtin").lsp_dynamic_workspace_symbols,
            "[W]orkspace [S]ymbols"
          )

          -- Rename the variable under your cursor.
          map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map("<leader>a", vim.lsp.buf.code_action, "Code [A]ction", { "n", "x" })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

          -- map debugging keys
          -- {
          --   "<F5>",
          --   function()
          --     require("dap").continue()
          --   end,
          --   desc = "Debug: Start/Continue",
          -- },
          -- {
          --   "<F1>",
          --   function()
          --     require("dap").step_into()
          --   end,
          --   desc = "Debug: Step Into",
          -- },
          -- {
          --   "<F2>",
          --   function()
          --     require("dap").step_over()
          --   end,
          --   desc = "Debug: Step Over",
          -- },
          -- {
          --   "<F3>",
          --   function()
          --     require("dap").step_out()
          --   end,
          --   desc = "Debug: Step Out",
          -- },
          -- {
          --   "<leader>b",
          --   function()
          --     require("dap").toggle_breakpoint()
          --   end,
          --   desc = "Debug: Toggle Breakpoint",
          -- },
          -- {
          --   "<leader>B",
          --   function()
          --     require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
          --   end,
          --   desc = "Debug: Set Breakpoint",
          -- },
          -- -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
          -- {
          --   "<F7>",
          --   function()
          --     require("dapui").toggle()
          --   end,
          --   desc = "Debug: See last session result.",
          -- },

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
              vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
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
              group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({
                  group = "kickstart-lsp-highlight",
                  buffer = event2.buf,
                })
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
            end, "[T]oggle Inlay [H]ints")
          end
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      -- capabilities =
      --   vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())
      capabilities =
        vim.tbl_deep_extend("force", capabilities, require("blink.cmp").get_lsp_capabilities())

      -- Enable the following language servers
      local servers = {
        clangd = {},
        gopls = {
          settings = {
            gopls = {
              staticcheck = true,
            },
          },
        },
        pyright = {},
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = "Replace",
              },
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      }

      -- manually enable sourcekit for swift
      require("lspconfig").sourcekit.setup({})

      -- Ensure the servers and tools above are installed
      require("mason").setup()

      -- You can add other tools here that you want Mason to install
      --  for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        "stylua",
      })
      require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

      require("mason-lspconfig").setup({
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for tsserver)
            server.capabilities =
              vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
            require("lspconfig")[server_name].setup(server)
          end,
        },
      })

      require("mason-nvim-dap").setup({
        automatic_installation = true,
        handlers = {},
        ensure_installed = {
          "codelldb",
        },
      })
    end,
  },
}
