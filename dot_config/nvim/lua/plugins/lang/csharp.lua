-- C# development, mainly for Godot
-- the coreclr debug adapter is configured in plugins/dap.lua

return {
  {
    "seblyng/roslyn.nvim",
    ft = "cs",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    -- let roslyn's own file watcher handle changes
    opts = { filewatching = "roslyn" },
    init = function()
      -- ensure roslyn starts file watching before vim.lsp.enable
      vim.lsp.config("roslyn", {
        capabilities = {
          workspace = {
            didChangeWatchedFiles = { dynamicRegistration = false },
          },
        },
      })

      -- hover-docs extends roslyn's docs hover with extra information
      -- ensure the lua glue code exists before loading
      local ok, hover_docs = pcall(require, "hover-docs")
      if ok then
        hover_docs.setup()

        vim.api.nvim_create_autocmd("LspAttach", {
          group = vim.api.nvim_create_augroup(
            "roslyn-hover-docs-definition",
            { clear = true }
          ),
          callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if
              not client
              or (client.name ~= "roslyn" and client.name ~= "roslyn_ls")
            then
              return
            end

            vim.keymap.set("n", "gd", function()
              hover_docs.goto_definition(function()
                Snacks.picker.lsp_definitions()
              end)
            end, {
              buffer = args.buf,
              desc = "[G]oto [D]efinition (+inheritdoc)",
            })
          end,
        })
      end

      -- Roslyn generates the /// doc-comment stub using the VS-internal textDocument/_vs_onAutoInsert method
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup(
          "roslyn-auto-insert",
          { clear = true }
        ),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if
            not client
            or (client.name ~= "roslyn" and client.name ~= "roslyn_ls")
          then
            return
          end

          vim.api.nvim_create_autocmd("InsertCharPre", {
            desc = "Roslyn: generate an XML doc comment stub on '///'",
            buffer = args.buf,
            callback = function()
              if vim.v.char ~= "/" then
                return
              end

              local bufnr = vim.api.nvim_get_current_buf()
              local cursor = vim.api.nvim_win_get_cursor(0)
              local params = {
                _vs_textDocument = { uri = vim.uri_from_bufnr(bufnr) },
                _vs_position = {
                  line = cursor[1] - 1,
                  character = cursor[2] + 1,
                },
                _vs_ch = "/",
                _vs_options = {
                  tabSize = vim.bo[bufnr].tabstop,
                  insertSpaces = vim.bo[bufnr].expandtab,
                },
              }

              -- defer so the '/' lands in the buffer (and its didChange is sent)
              -- before Roslyn computes the stub against the updated document
              vim.defer_fn(function()
                client:request(
                  -- a Roslyn extension, not part of the LSP method enum
                  ---@diagnostic disable-next-line: param-type-mismatch
                  "textDocument/_vs_onAutoInsert",
                  params,
                  function(err, result)
                    if err or not result then
                      return
                    end
                    -- vim.snippet.expand re-applies the current line's indent to
                    -- every continuation line, but Roslyn already baked it into
                    -- newText, so strip one copy to avoid double-indenting
                    local text = result._vs_textEdit.newText
                    local indent = vim.api.nvim_get_current_line():match("^%s*")
                    if indent and indent ~= "" then
                      text = text:gsub("\n" .. indent, "\n")
                    end
                    vim.snippet.expand(text)
                  end,
                  bufnr
                )
              end, 1)
            end,
          })
        end,
      })
    end,
  },
}
