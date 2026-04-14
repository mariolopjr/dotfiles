-- Helix-style leader hint panel, vscode-neovim only.
-- which-key.nvim (folke) is disabled in vscode via its own cond guard;
-- this spec activates only inside vscode and requires no external plugins.
return {
  {
    -- Virtual plugin entry — no external repo needed.
    -- We use dir pointing to our own lua dir so lazy.nvim can manage it.
    dir = vim.fn.stdpath("config"),
    name = "vscode-whichkey",
    cond = function() return vim.g.vscode ~= nil end,
    event = "VimEnter",
    config = function()
      require("vscode-whichkey").setup({
        position = "bottom", -- "bottom" | "left" | "right"
        height = 12,         -- lines tall (bottom only)
        width = 50,          -- cols wide (left/right only)
        col_width = 22,      -- chars per hint column
        cols = 4,            -- hint columns across
      })
    end,
  },
}
