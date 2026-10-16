-- File tree sidebar (VS Code explorer). Plain-text glyphs: no Nerd Font needed.
return {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFindFile" },
    keys = {
        { "<C-b>", "<cmd>NvimTreeToggle<cr>", desc = "Toggle explorer" },
        { "<C-M-x>", "<cmd>NvimTreeFindFile<cr>", desc = "Reveal file in explorer" },
        { "<leader>e", "<cmd>NvimTreeFindFile<cr>", desc = "Reveal file in explorer" },
    },
    init = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
    end,
    opts = {
        view = { width = 32 },
        update_focused_file = { enable = true },
        filters = { git_ignored = false },
        renderer = {
            group_empty = true,
            icons = {
                show = { file = false, folder = false, git = true, modified = true },
                glyphs = {
                    folder = { arrow_closed = ">", arrow_open = "v" },
                    git = {
                        unstaged = "M", staged = "S", unmerged = "!", renamed = "R",
                        untracked = "U", deleted = "D", ignored = "◌",
                    },
                },
            },
        },
    },
}
