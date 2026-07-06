-- Non-plugin keymaps, plugin keymaps live in their lazy specs

local map = vim.keymap.set

-- clear search highlight, see :help hlsearch
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- train away the arrow keys in normal mode
map("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
map("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
map("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
map("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- exit terminal mode with something easier than <C-\><C-n>
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- LSP keymaps for attached buffers
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-attach-keymaps", { clear = true }),
  callback = function(args)
    local buf = args.buf
    map(
      "n",
      "gK",
      vim.lsp.buf.signature_help,
      { desc = "Signature Help", buffer = buf }
    )
    map(
      "n",
      "gD",
      vim.lsp.buf.declaration,
      { desc = "[G]oto [D]eclaration", buffer = buf }
    )
    map(
      "n",
      "<leader>cr",
      vim.lsp.buf.rename,
      { desc = "[C]ode [R]ename", buffer = buf }
    )
    map(
      { "n", "x" },
      "<leader>ca",
      vim.lsp.buf.code_action,
      { desc = "[C]ode [A]ction", buffer = buf }
    )
    map(
      { "n", "x" },
      "ga",
      vim.lsp.buf.code_action,
      { desc = "Code Action", buffer = buf }
    )
    map("n", "<leader>cA", function()
      vim.lsp.buf.code_action({
        context = { only = { "source.fixAll" }, diagnostics = {} },
        apply = true,
      })
    end, { desc = "[C]ode Fix [A]ll (whole document)", buffer = buf })
    map("n", "<leader>ch", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end, { desc = "[C]ode Toggle Inlay [H]ints", buffer = buf })
  end,
})

-- diagnostic motions, the built-in ]d and [d do not open the float
local function diagnostic_goto(next, severity)
  return function()
    vim.diagnostic.jump({
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = true,
    })
  end
end

map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
map("n", "[d", diagnostic_goto(false), { desc = "Prev Diagnostic" })
map("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
map("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Prev Error" })
map("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
map("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Prev Warning" })

-- tab pages
map("n", "<leader>tn", "<cmd>tabnew<CR>", { desc = "[N]ew tab" })
map(
  "n",
  "<leader>tf",
  "<cmd>tabedit %<CR>",
  { desc = "Current [F]ile in new tab" }
)
map("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "[C]lose tab" })
map("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "Close [O]ther tabs" })
map("n", "<leader>tl", "<cmd>tabnext<CR>", { desc = "Next tab ([L])" })
map("n", "<leader>th", "<cmd>tabprevious<CR>", { desc = "Previous tab ([H])" })
map("n", "<leader>t.", "<cmd>tabmove +1<CR>", { desc = "Move tab right" })
map("n", "<leader>t,", "<cmd>tabmove -1<CR>", { desc = "Move tab left" })

-- buffers and files
map("n", "<leader>bd", ":bd<CR>", { desc = "[B]uffer [D]elete", silent = true })
map("n", "<leader>fs", ":w<CR>", { desc = "[F]ile [S]ave", silent = true })
map("n", "<leader>fq", ":q<CR>", { desc = "[F]ile [Q]uit", silent = true })
map("n", "<leader>q", ":cquit<CR>", { desc = "[Q]uit Neovim", silent = true })
