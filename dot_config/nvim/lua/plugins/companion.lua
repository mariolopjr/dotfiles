local M = {}

M.setup = function()
  -- install
  vim.pack.add({
    { src = "https://github.com/olimorris/codecompanion.nvim" },
  })
end

if vim.g.use_vim_pack then
  return M
end

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
        agent = {
          adapter = "copilot",
        },
        chat = {
          adapter = "copilot",
        },
        inline = {
          adapter = "copilot",
        },
      },
    },
    keys = {
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
        "<leader>ai",
        function()
          local input = vim.fn.input("Enter text for [A]I [I]nline Chat: ")
          if input ~= "" then
            require("codecompanion").inline({
              user_prompt = input,
            })
          end
        end,
        mode = { "n", "v" },
        desc = "[A]I [I]line Chat",
      },
      {
        "ga",
        function()
          require("codecompanion").add({})
        end,
        mode = { "n", "v" },
        desc = "Send selected text to AI Chat",
      },
    },
    config = function(_, opts)
      local codecompanion = require("codecompanion")
      codecompanion.setup(opts)

      vim.cmd([[cab cc CodeCompanion]])
    end,
  },
}
