local bufnr = vim.api.nvim_get_current_buf()
local footnotes = require("util.footnotes")
local mdref = require("util.mdref")

-- insert a reference-style link and auto-create its definition under
-- `# References`, prompting for the label and the URL
vim.keymap.set("n", "<leader>oi", function()
  mdref.insert("n")
end, { buffer = bufnr, desc = "[O]bsidian [I]nsert reference" })

-- insert-mode keybinding
vim.keymap.set("i", "<M-r>", function()
  mdref.insert("i")
end, { buffer = bufnr, desc = "Insert reference" })

-- renumber footnotes into reading order, returns if refs and defs are inconsistent
vim.api.nvim_buf_create_user_command(bufnr, "FootnoteRenumber", function()
  footnotes.renumber(0)
end, { desc = "Renumber footnotes into reading order" })

vim.keymap.set("n", "<leader>on", function()
  footnotes.renumber(0)
end, { buffer = bufnr, desc = "[O]bsidian re[N]umber footnotes" })
