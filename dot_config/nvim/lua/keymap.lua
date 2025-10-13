local M = {}

local keymap = vim.keymap
local map = vim.keymap.set
function M.setup()
  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

  -- TIP: Disable arrow keys in normal mode
  keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
  keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
  keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
  keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

  -- Add empty lines before and after cursor line
  vim.keymap.set(
    "n",
    "gO",
    "<Cmd>call append(line('.') - 1, repeat([''], v:count1))<CR>",
    { desc = "Add line before no insert" }
  )
  vim.keymap.set(
    "n",
    "go",
    "<Cmd>call append(line('.'),     repeat([''], v:count1))<CR>",
    { desc = "Add line after no insert" }
  )

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

  -- Open lazy plugin github page
  local function custom_gx()
    local line = vim.api.nvim_get_current_line()
    -- Match: { "author/repo",
    local repo = line:match('{%s*"([%w%-_]+/[%w%-_%.]+)",')
    if not repo then
      -- Also match: "author/repo",
      repo = line:match('"([%w%-_]+/[%w%-_%.]+)",')
    end
    if repo then
      local url = "https://github.com/" .. repo
      vim.fn.jobstart({ "open", url }, { detach = true })
      return
    end
    -- Fallback to default gx
    vim.api.nvim_feedkeys("gx", "n", false)
  end

  keymap.set(
    "n",
    "gx",
    custom_gx,
    { desc = "Open URL or plugin repo in browser" }
  )

  -- LSP keymap
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
    callback = function(args)
      local buf = args.buf

      keymap.set(
        "n",
        "gK",
        vim.lsp.buf.signature_help,
        { desc = "Signature Help", buffer = buf }
      )
      keymap.set(
        "n",
        "<leader>cr",
        vim.lsp.buf.rename,
        { desc = "[C]ode [R]ename", buffer = buf }
      )
      keymap.set(
        { "n", "x" },
        "<leader>ca",
        vim.lsp.buf.code_action,
        { desc = "[C]ode [A]ction", buffer = buf }
      )
      keymap.set(
        "n",
        "gD",
        vim.lsp.buf.declaration,
        { desc = "[G]oto [D]eclaration", buffer = buf }
      )
      keymap.set("n", "<leader>ch", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end, { desc = "[C]ode Toggle Inlay [H]ints", buffer = buf })
    end,
  })

  -- Diagnostic keymaps
  local diagnostic_goto = function(next, severity)
    return function()
      vim.diagnostic.jump({
        count = (next and 1 or -1) * vim.v.count1,
        severity = severity and vim.diagnostic.severity[severity] or nil,
        float = true,
      })
    end
  end

  map("n", "[q", vim.cmd.cprev, { desc = "Previous Quickfix" })
  map("n", "]q", vim.cmd.cnext, { desc = "Next Quickfix" })
  map(
    "n",
    "<leader>cd",
    vim.diagnostic.open_float,
    { desc = "Line Diagnostics" }
  )
  map("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
  map("n", "[d", diagnostic_goto(false), { desc = "Prev Diagnostic" })
  map("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
  map("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Prev Error" })
  map("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
  map("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Prev Warning" })

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  --
  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
  keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

  -- Add autosaving
  vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
    callback = function()
      if vim.bo.modified and not vim.bo.readonly and vim.bo.buftype == "" then
        vim.cmd("silent update")
      end
    end,
  })

  keymap.set(
    "n",
    "<leader>bd",
    ":bd<CR>",
    { desc = "[B]uffer [D]elete", noremap = true, silent = true }
  )
  keymap.set(
    "n",
    "<leader>fs",
    ":w<CR>",
    { desc = "[F]ile [S]ave", noremap = true, silent = true }
  )
  keymap.set(
    "n",
    "<leader>fq",
    ":q<CR>",
    { desc = "[F]ile [Q]uit", noremap = true, silent = true }
  )
  keymap.set(
    "n",
    "<leader>q",
    ":cquit<CR>",
    { desc = "[Q]uit Neovim", noremap = true, silent = true }
  )
end

return M
