local M = {}

local keymap = vim.keymap
local comment = {
    selected = function()
        vim.fn.VSCodeNotifyRange('editor.action.commentLine', vim.fn.line('v'), vim.fn.line('.'), 1)
    end
}

function M.setup()
    -- keymap.set({ 'n', 'v', 'o' }, 'gc', comment.selected)
    -- keymap.set('n', 'gcc', comment.selected)
end

return M
