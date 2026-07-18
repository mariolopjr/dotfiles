return {
  "Bekaboo/dropbar.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    {
      "<leader>;",
      function()
        require("dropbar.api").pick()
      end,
      desc = "Breadcrumb pick",
    },
  },
}
