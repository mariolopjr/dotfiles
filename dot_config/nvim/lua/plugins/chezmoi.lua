return {
  {
    -- highlighting for chezmoi template files
    "alker0/chezmoi.vim",
    init = function()
      vim.g["chezmoi#use_tmp_buffer"] = 1
      vim.g["chezmoi#source_dir_path"] = os.getenv("HOME")
        .. "/.local/share/chezmoi"

      -- update lazy.nvim lockfile
      vim.api.nvim_create_autocmd("User", {
        pattern = { "LazyInstall", "LazyUpdate", "LazySync", "LazyClean" },
        group = vim.api.nvim_create_augroup(
          "chezmoi_update_lock",
          { clear = true }
        ),
        callback = function(_)
          -- lazy.nvim fires this event before it writes lazy-lock.json, so
          -- defer the chezmoi add until after the lockfile has been updated
          vim.schedule(function()
            local lock_file = vim.fn.stdpath("config") .. "/lazy-lock.json"
            vim.fn.system({ "chezmoi", "add", lock_file })
          end)
        end,
      })
    end,
  },
}
