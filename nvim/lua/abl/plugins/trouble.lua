-- Problems panel (VS Code Ctrl+Shift+M): diagnostics grouped by file, updated as they change
return {
    "folke/trouble.nvim",
    cmd = "Trouble",
    keys = {
        { "<C-S-m>", "<cmd>Trouble diagnostics toggle<cr>", desc = "Problems" },
        { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Problems" },
        { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Problems in this file" },
    },
    opts = {
        focus = true, -- jump into the panel when it opens, like VS Code
        -- One group per file, as in VS Code (the default nests files under directories)
        modes = {
            diagnostics = { groups = { { "filename", format = "{file_icon} {filename} {count}" } } },
        },
        -- Plain characters instead of the default Nerd Font glyphs
        icons = {
            indent = { fold_open = "▾ ", fold_closed = "▸ " },
            folder_open = "",
            folder_closed = "",
        },
    },
}
