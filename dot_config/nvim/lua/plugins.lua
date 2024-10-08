local M = {}

function M.setup()
    -- Setup lazy.nvim
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.loop.fs_stat(lazypath) then
        vim.fn.system({
            "git",
            "clone",
            "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git",
            "--branch=stable",
            lazypath,
        })
    end
    vim.opt.rtp:prepend(lazypath)

    -- plugins
    require("lazy").setup({
        --"terrortylor/nvim-comment",
        "tpope/vim-commentary",
        "tpope/vim-repeat",
        {
            "ggandor/leap.nvim",
            depedencies = { "tpope/vim-repeat" },
            config = function()
                require("leap").create_default_mappings()
            end,
        },
    })
end

return M
