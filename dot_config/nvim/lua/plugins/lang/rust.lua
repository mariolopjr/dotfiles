-- Rust development, keymaps live in after/ftplugin/rust.lua

return {
  {
    "mrcjkb/rustaceanvim",
    version = "^9",
    lazy = false,
    init = function()
      -- codelldb from .chezmoiexternal renders Rust values properly
      -- fall back to the llvm keg's lldb-dap until codelldb has been fetched
      vim.g.rustaceanvim = function()
        -- in order for codelldb to render Rust values properly, formatters from
        -- the active toolchain need to have each type definition inlined
        -- manually
        local function enrich(cfg, on_config)
          local final = vim.deepcopy(cfg)
          local sysroot = vim
            .system({ "rustc", "--print", "sysroot" }, { cwd = cfg.cwd, text = true })
            :wait()
          local root = vim.trim(sysroot.stdout or "")
          if sysroot.code == 0 and root ~= "" then
            local etc = root .. "/lib/rustlib/etc"
            local cmds =
              { 'command script import "' .. etc .. '/lldb_lookup.py"' }
            if vim.fn.filereadable(etc .. "/lldb_commands") == 1 then
              for _, line in ipairs(vim.fn.readfile(etc .. "/lldb_commands")) do
                local t = vim.trim(line)
                if t ~= "" and t:sub(1, 1) ~= "#" then
                  cmds[#cmds + 1] = t
                end
              end
            end
            final.initCommands = vim.list_extend(final.initCommands or {}, cmds)
          end
          on_config(final)
        end

        local dir = vim.fn.expand("~/.local/share/codelldb")
        local codelldb = dir .. "/adapter/codelldb"

        ---@type table
        local adapter
        if vim.fn.executable(codelldb) == 1 then
          local libext = vim.uv.os_uname().sysname == "Linux" and ".so"
            or ".dylib"
          adapter = require("rustaceanvim.config").get_codelldb_adapter(
            codelldb,
            dir .. "/lldb/lib/liblldb" .. libext
          )
        else
          local lldb_dap = vim.fn.exepath("lldb-dap")
          if lldb_dap == "" then
            lldb_dap = "/opt/homebrew/opt/llvm/bin/lldb-dap"
          end
          adapter = { type = "executable", command = lldb_dap, name = "lldb" }
        end
        adapter.enrich_config = enrich

        return {
          dap = { adapter = adapter },
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
              for _, name in ipairs({ ".cargo/config.toml", ".cargo/config" }) do
                local f = io.open((project_root or ".") .. "/" .. name, "r")
                if f then
                  local body = f:read("*a")
                  f:close()
                  if body and body:match('target%s*=%s*"[^"]*none[^"]*"') then
                    local ra = settings["rust-analyzer"]
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
  },
}
