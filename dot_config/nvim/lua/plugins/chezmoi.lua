local M = {}

M.pick_chezmoi = function()
  local results = require("chezmoi.commands").list({
    args = {
      "--path-style",
      "absolute",
      "--include",
      "files",
      "--exclude",
      "externals",
    },
  })
  local items = {}

  for _, czFile in ipairs(results) do
    table.insert(items, {
      text = czFile,
      file = czFile,
    })
  end

  ---@type snacks.picker.Config
  local opts = {
    items = items,
    confirm = function(picker, item)
      picker:close()
      require("chezmoi.commands").edit({
        targets = { item.text },
        args = { "--watch" },
      })
    end,
  }
  require("snacks").picker.pick(opts)
end

M.setup = function()
  -- install
  vim.pack.add({
    { src = "https://github.com/alker0/chezmoi.vim" },
    { src = "https://github.com/xvzc/chezmoi.nvim" },
  })

  -- options
  local opts = {
    edit = {
      watch = false,
      force = false,
    },
    notification = {
      on_open = true,
      on_apply = true,
      on_watch = false,
    },
  }

  -- setup
  -- chezmoi file syntax highlighting
  vim.g["chezmoi#use_tmp_buffer"] = 1
  vim.g["chezmoi#source_dir_path"] = os.getenv("HOME")
    .. "/.local/share/chezmoi"

  local chezmoi = require("chezmoi")
  chezmoi.setup(opts)

  -- run chezmoi edit on file enter
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { os.getenv("HOME") .. "/.local/share/chezmoi/*" },
    callback = function()
      vim.schedule(require("chezmoi.commands.__edit").watch)
    end,
  })

  -- keymap
  local map = vim.keymap.set
  map("n", "<leader>sz", M.pick_chezmoi, { desc = "Chezmoi" })
end

if vim.g.use_vim_pack then
  return M
end

return {
  {
    -- highlighting for chezmoi files template files
    "alker0/chezmoi.vim",
    init = function()
      vim.g["chezmoi#use_tmp_buffer"] = 1
      vim.g["chezmoi#source_dir_path"] = os.getenv("HOME")
        .. "/.local/share/chezmoi"
    end,
  },
  {
    "xvzc/chezmoi.nvim",
    keys = {
      {
        "<leader>sz",
        M.pick_chezmoi,
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
