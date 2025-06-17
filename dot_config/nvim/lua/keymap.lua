local M = {}

local keymap = vim.keymap
function M.setup()
  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

  -- Diagnostic keymaps
  keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  --
  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
  keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

  -- TIP: Disable arrow keys in normal mode
  keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
  keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
  keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
  keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  -- Highlight when yanking (copying) text
  --  Try it with `yap` in normal mode
  --  See `:help vim.highlight.on_yank()`
  vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
      vim.highlight.on_yank()
    end,
  })
end

-- LSP keymap
keymap.set("n", "gK", vim.lsp.buf.signature_help, { desc = "Signature Help" })
keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { desc = "[C]ode [R]ename" })
keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "[C]ode [A]ction" })
keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "[G]oto [D]eclaration" })

-- highlight references of a word under cursor
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
  callback = function(event)
    -- The following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    --    See `:help CursorHold` for information about when this is executed
    --
    -- When you move your cursor, the highlights will be cleared (the second autocommand).
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
      local highlight_augroup = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd("LspDetach", {
        group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds({
            group = "lsp-highlight",
            buffer = event2.buf,
          })
        end,
      })
    end

    -- The following code creates a keymap to toggle inlay hints in your
    -- code, if the language server you are using supports them
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      keymap.set("n", "<leader>ch", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({
          bufnr = event.buf,
        }))
      end, { desc = "[C]ode Toggle Inlay [H]ints" })
    end
  end,
})

-- Add autosaving and saving with <leader>fw
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  callback = function()
    if vim.bo.modified and not vim.bo.readonly and vim.bo.buftype == "" then
      vim.cmd("silent update")
    end
  end,
})

keymap.set("n", "<leader>bd", ":bd<CR>", { desc = "[B]uffer [D]elete", noremap = true, silent = true })
keymap.set("n", "<leader>fw", ":w<CR>", { desc = "[F]ile [W]rite", noremap = true, silent = true })
keymap.set("n", "<leader>fq", ":q<CR>", { desc = "[F]ile [Q]uit", noremap = true, silent = true })
keymap.set("n", "<leader>Q", ":cquit<CR>", { desc = "[Q]uit Neovim", noremap = true, silent = true })

return M
