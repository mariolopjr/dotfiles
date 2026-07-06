-- C# development, mainly for Godot
-- the coreclr debug adapter is configured in plugins/dap.lua

return {
  {
    "seblyng/roslyn.nvim",
    ft = "cs",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {},
    init = function()
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
