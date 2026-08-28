-- Rust development, keymaps live in after/ftplugin/rust.lua

vim.api.nvim_create_user_command("CargoInfo", function()
  vim.notify(table.concat(require("util.rust").report(), "\n"))
end, {
  desc = "Report the cargo root, godot project and debug adapter for this buffer",
})

return {
  {
    "mrcjkb/rustaceanvim",
    version = "^9",
    lazy = false,
    init = function()
      -- the adapter and its rust formatters live in util.rust, plugins/dap.lua
      -- registers the same one so an attach to godot debugs like a testable does
      vim.g.rustaceanvim = function()
        return {
          dap = { adapter = require("util.rust").adapter() },
          tools = {
            test_executor = "background",
            float_win_config = {
              border = "rounded",
              max_width = 90,
            },
          },
          server = {
            default_settings = {
              ["rust-analyzer"] = {
                hover = {
                  memoryLayout = { niches = true },
                  show = { traitAssocItems = 5 },
                },
                -- hoverboard resolves doc references through workspace/symbol,
                -- whose fuzzy matching buries exact short names under the
                -- default cap of 128
                workspace = {
                  symbol = { search = { limit = 2048 } },
                },
                -- typeHints, parameterHints and chainingHints are on by
                -- default
                inlayHints = {
                  bindingModeHints = { enable = true },
                  closureReturnTypeHints = { enable = "with_block" },
                  closureCaptureHints = { enable = true },
                  discriminantHints = { enable = "fieldless" },
                  expressionAdjustmentHints = { enable = "reborrow" },
                  lifetimeElisionHints = {
                    enable = "skip_trivial",
                    useParameterNames = true,
                  },
                  implicitDrops = { enable = true },
                  rangeExclusiveHints = { enable = true },
                },
                cargo = {
                  -- separate target dir so a terminal `cargo build` and
                  -- rust-analyzer stop stalling on the same target/ lock. RA
                  -- uses target/rust-analyzer, the cargo cli keeps target/debug,
                  -- so `just run` and the profiling recipes are separate
                  targetDir = true,
                },
                imports = {
                  granularity = { group = "module" },
                  prefix = "crate",
                },
                lens = {
                  implementations = { enable = true },
                  references = {
                    adt = { enable = true },
                    trait = { enable = true },
                  },
                },
              },
            },
            -- rust-analyzer defaults to `cargo check --all-targets`, which builds
            -- the crate as a test binary and links libtest. libtest needs std, so
            -- on a bare-metal `*-none-*` target the check fails with E0463. Detect
            -- such crates from .cargo/config.toml and drop --all-targets for them
            settings = function(project_root, default_settings)
              local rs = require("rustaceanvim.config.server")
              -- preserves rustaceanvim's clippy-on-save injection
              local settings = rs.load_rust_analyzer_settings(project_root, {
                default_settings = default_settings,
              })
              local ra = settings["rust-analyzer"]
              if vim.g.rustanalyzer_features ~= nil then
                ra.cargo = ra.cargo or {}
                ra.cargo.features = vim.g.rustanalyzer_features
              end
              for _, name in ipairs({ ".cargo/config.toml", ".cargo/config" }) do
                local f = io.open((project_root or ".") .. "/" .. name, "r")
                if f then
                  local body = f:read("*a")
                  f:close()
                  if body and body:match('target%s*=%s*"[^"]*none[^"]*"') then
                    ra.cargo = ra.cargo or {}
                    ra.cargo.allTargets = false
                    break
                  end
                end
              end
              return settings
            end,
          },
        }
      end
    end,
  },
  {
    "saecki/crates.nvim",
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    opts = {
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
    config = function(_, opts)
      require("crates").setup(opts)

      -- dependency management keymaps, only in Cargo.toml buffers so they do
      -- not shadow the .rs `<leader>c` maps
      vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("crates-keymaps", { clear = true }),
        pattern = "Cargo.toml",
        callback = function(ev)
          local crates = require("crates")
          local function map(lhs, rhs, desc)
            vim.keymap.set(
              "n",
              lhs,
              rhs,
              { silent = true, buffer = ev.buf, desc = desc }
            )
          end
          map("<leader>cu", crates.update_crate, "[C]rate [U]pdate")
          map("<leader>cU", crates.upgrade_all_crates, "[C]rate [U]pgrade all")
          map("<leader>cv", crates.show_versions_popup, "[C]rate [V]ersions")
          map("<leader>cF", crates.show_features_popup, "[C]rate [F]eatures")
          map(
            "<leader>cD",
            crates.show_dependencies_popup,
            "[C]rate [D]ependencies"
          )
          map("<leader>co", crates.open_documentation, "[C]rate [O]pen docs")
        end,
      })
    end,
  },
}
