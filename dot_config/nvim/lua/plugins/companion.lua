return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      { "MeanderingProgrammer/render-markdown.nvim", ft = { "markdown", "codecompanion" } },
    },
    opts = {
      --
    },
    keys = {
      {
        "<leader>aa",
        function()
          require("codecompanion").actions({})
        end,
        mode = { "n", "v" },
        desc = "[A]I Actions",
      },
      {
        "<leader>ac",
        function()
          require("codecompanion").toggle()
        end,
        mode = { "n", "v" },
        desc = "[A]I Actions",
      },
      {
        "ga",
        function()
          require("codecompanion").add({})
        end,
        mode = { "n", "v" },
        desc = "[A]I Actions",
      },
    },
    config = function(_, opts)
      local codecompanion = require("codecompanion")
      vim.cmd([[cab cc CodeCompanion]])
    end,
  },
}
