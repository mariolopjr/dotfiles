return {
  {
    -- highlighting for chezmoi files template files
    "alker0/chezmoi.vim",
    enabled = not vim.g.vscode,
    init = function()
      vim.g["chezmoi#use_tmp_buffer"] = 1
      vim.g["chezmoi#source_dir_path"] = os.getenv("HOME") ..
          "/.local/share/chezmoi"
    end,
  },
  {
    "xvzc/chezmoi.nvim",
    enabled = not vim.g.vscode,
    keys = {
      {
        "<leader>sz",
        function()
          local fzf_lua = require("fzf-lua")
          local results = require("chezmoi.commands").list()
          local chezmoi = require("chezmoi.commands")

          local opts = {
            fzf_opts = {},
            fzf_colors = true,
            actions = {
              ["default"] = function(selected)
                chezmoi.edit({
                  targets = { "~/" .. selected[1] },
                  args = { "--watch" },
                })
              end,
            },
          }
          fzf_lua.fzf_exec(results, opts)
        end,
        desc = "Chezmoi",
      },
    },
    opts = {
      edit = {
        watch = false,
        force = false,
      },
      notification = {
        on_open = true,
        on_apply = true,
        on_watch = false,
      },
    },
    init = function()
      -- run chezmoi edit on file enter
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { os.getenv("HOME") .. "/.local/share/chezmoi/*" },
        callback = function()
          vim.schedule(require("chezmoi.commands.__edit").watch)
        end,
      })
    end,
  },
}
