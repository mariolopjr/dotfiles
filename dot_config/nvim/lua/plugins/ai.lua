return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "codecompanion" },
      },
    },
    opts = {
      display = {
        diff = {
          provider = "mini_diff",
        },
      },
      strategies = {
        -- chat and agentic edits run on the Claude subscription over ACP
        chat = {
          adapter = "claude_code",
        },
        -- inline and cmd use HTTP adapters so they cannot run on ACP
        inline = {
          adapter = "claude_code",
        },
        cmd = {
          adapter = "claude_code",
        },
        background = {
          chat = {
            opts = {
              enabled = false,
            },
          },
        },
      },
      adapters = {
        acp = {
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              -- default the session to Sonnet, the agent otherwise defaults to Opus
              defaults = {
                model = "sonnet",
              },
              env = {
                -- No token by default, rely on the already-authenticated `claude` CLI login
                CLAUDE_CODE_OAUTH_TOKEN = function()
                  return vim.env.CLAUDE_CODE_OAUTH_TOKEN
                end,
              },
            })
          end,
        },
      },
    },
    keys = {
      {
        "<C-a>",
        function()
          require("codecompanion").actions({})
        end,
        mode = { "n", "v" },
        desc = "AI Code Actions",
      },
      {
        "<leader>aa",
        function()
          require("codecompanion").actions({})
        end,
        mode = { "n", "v" },
        desc = "[A]I [A]ctions",
      },
      {
        "<leader>ac",
        function()
          require("codecompanion").toggle()
        end,
        mode = { "n", "v" },
        desc = "[A]I [C]hat",
      },
      {
        -- inline doesn't work on the subscription, repurpose to instruct the agent,
        -- in visual mode attach the selection first, then focus the chat in
        -- insert so you can type the edit instruction (the agent edits files
        -- over ACP). Distinct from `gA` which stays in the source buffer
        "<leader>ai",
        function()
          local cc = require("codecompanion")
          if vim.fn.mode():match("^[vV\022]") then
            cc.add({})
          end
          local chat = cc.last_chat() or cc.chat()
          if chat and chat.ui then
            chat.ui:open()
          end
          vim.schedule(function()
            vim.cmd("startinsert")
          end)
        end,
        mode = { "n", "v" },
        desc = "[A]I [I]nstruct edit",
      },
      {
        "gA",
        function()
          require("codecompanion").add({})
        end,
        mode = { "x" },
        desc = "Send selected text to AI Chat",
      },
    },
    config = function(_, opts)
      require("codecompanion").setup(opts)

      -- chat winbar, adapter/model, context count, tokens
      pcall(function()
        require("util.cc_winbar").setup()
      end)

      vim.cmd([[cab cc CodeCompanion]])
    end,
  },
}
