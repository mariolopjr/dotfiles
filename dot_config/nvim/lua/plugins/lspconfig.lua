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
      "saghen/blink.cmp",

      -- add neoconf support
      "folke/neoconf.nvim",

      -- setup dap with lsp
      {
        "mfussenegger/nvim-dap",
        dependencies = {
          "rcarriga/nvim-dap-ui",
          "nvim-neotest/nvim-nio",
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
      require("neoconf").setup()

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
          map(
            "<leader>cd",
            require("telescope.builtin").lsp_type_definitions,
            "[C]ode Type [D]efinition"
          )

          -- Fuzzy find all the symbols in your current document.
          map("<leader>cs", require("telescope.builtin").lsp_document_symbols, "[C]ode [S]ymbols")

          -- Fuzzy find all the symbols in your current workspace.
          map(
            "<leader>cw",
            require("telescope.builtin").lsp_dynamic_workspace_symbols,
            "[C]ode Workspace [S]ymbols"
          )

          -- Rename the variable under your cursor.
          map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

          -- map debugging keys
          local dap = require("dap")
          map("<F1>", dap.step_into, "Debug: Step Into")
          map("<F2>", dap.step_over, "Debug: Step Over")
          map("<F3>", dap.step_out, "Debug: Step Out")
          map("<F4>", dap.continue, "Debug: Start/Continue")
          map("<F5>", require("dapui").toggle, "Debug: Last Session Result")
          map("<leader>db", dap.toggle_breakpoint, "Debug: Toggle Breakpoint")
          map("<leader>dB", function()
            dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
          end, "Debug: Set Breakpoint")

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
      capabilities =
        vim.tbl_deep_extend("force", capabilities, require("blink.cmp").get_lsp_capabilities())

      -- enable language servers
      local lspconfig = require("lspconfig")

      lspconfig.clangd.setup({})
      lspconfig.fish_lsp.setup({})
      lspconfig.lua_ls.setup({
        settings = {
          Lua = {
            completion = {
              callSnippet = "Replace",
            },
            -- diagnostics = { disable = { 'missing-fields' } },
          },
        },
      })
    end,
  },
}
