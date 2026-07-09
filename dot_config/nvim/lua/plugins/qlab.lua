-- qlab local plugin for managing ledger
local dir = "~/Code/qlab/editors/nvim"

return {
  {
    name = "qlab.nvim",
    dir = dir,
    ft = "ledger",
    -- ensure this only loads if the repo exists locally
    enabled = function()
      return vim.uv.fs_stat(vim.fn.expand(dir)) ~= nil
    end,
  },
}
