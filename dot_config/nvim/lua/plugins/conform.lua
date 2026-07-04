return {
  { -- Autoformat
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "[C]ode [F]ormat",
      },
      {
        "<leader>pc",
        ":ConformInfo<CR>",
        desc = "Check Conform info",
      },
    },
    opts = {
      log_level = vim.log.levels.DEBUG,
      notify_on_error = true,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        local lsp_format_opt
        if disable_filetypes[vim.bo[bufnr].filetype] then
          lsp_format_opt = "never"
        else
          lsp_format_opt = "fallback"
        end
        return {
          timeout_ms = 500,
          lsp_format = lsp_format_opt,
        }
      end,
      formatters = {
        just = {
          -- use two spaces for indentation
          prepend_args = { "--indentation", "  " },
        },
        yq_json = {
          command = "yq",
          args = {
            "-P",
            "--output-format",
            "json",
            "--input-format",
            "json",
            ".",
          },
          stdin = true,
        },
        -- xmllint --format pretty-prints XML. --encode UTF-8 keeps literals
        -- like © instead of entity-escaping them, and tail -n +2 strips the
        -- <?xml?> declaration xmllint always prepends
        xmllint = {
          command = "sh",
          args = {
            "-c",
            "set -o pipefail; xmllint --format --encode UTF-8 - | tail -n +2",
          },
          env = { XMLLINT_INDENT = "  " },
          stdin = true,
        },
      },
      formatters_by_ft = {
        cs = { "csharpier" },
        css = { "stylelint" },
        lua = { "stylua" },
        go = { "gofmt" },
        just = { "just" },
        python = { "isort", "ruff_format" },
        rust = { "rustfmt" },
        sh = { "shellcheck" },
        json = { "yq_json" },
        html = { "prettier" },
        xml = { "xmllint" },
        yaml = { "yq" },
        zig = { "zigfmt" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
}
