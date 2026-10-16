return {
    {
        "rose-pine/neovim",
        name = "rose-pine",
        lazy = false,
        priority = 1000,
        config = function()
            require("rose-pine").setup({ variant = "moon", styles = { italic = false } })
            vim.cmd.colorscheme("rose-pine")
        end,
    },

    -- Popup listing the keys that follow <leader>, g, ], ... while you type
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            icons = { mappings = false },
            spec = {
                { "<leader>b", group = "buffer" },
                { "<leader>c", group = "claude / code" },
                { "<leader>f", group = "find" },
                { "<leader>g", group = "git" },
                { "<leader>u", group = "toggle" },
                { "<leader>x", group = "problems" },
            },
        },
    },

    -- Open buffers as tabs along the top
    {
        "akinsho/bufferline.nvim",
        version = "*",
        event = "VeryLazy",
        opts = {
            options = {
                show_buffer_icons = false,
                show_buffer_close_icons = true,
                diagnostics = "nvim_lsp",
                offsets = { { filetype = "NvimTree", text = "Explorer", separator = true } },
            },
        },
    },
}
