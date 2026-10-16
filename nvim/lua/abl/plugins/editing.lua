return {
    -- Completion: Tab or Enter accepts, Ctrl+Space opens the list
    {
        "saghen/blink.cmp",
        version = "1.*",
        event = { "InsertEnter", "CmdlineEnter" },
        dependencies = { "rafamadriz/friendly-snippets" },
        opts = {
            keymap = {
                preset = "super-tab",
                ["<CR>"] = { "accept", "fallback" },
            },
            completion = { documentation = { auto_show = true } },
            signature = { enabled = true },
        },
    },

    -- Auto-close brackets and quotes
    { "nvim-mini/mini.pairs", event = "InsertEnter", opts = {} },

    -- Git changes in the gutter, inline blame
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            on_attach = function(buf)
                local gs = require("gitsigns")
                local function map(lhs, rhs, desc)
                    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
                end
                map("]h", function() gs.nav_hunk("next") end, "Next change")
                map("[h", function() gs.nav_hunk("prev") end, "Previous change")
                map("<leader>gp", gs.preview_hunk, "Preview change")
                map("<leader>gr", gs.reset_hunk, "Revert change")
                map("<leader>gb", gs.toggle_current_line_blame, "Toggle line blame")
                map("<leader>gd", gs.diffthis, "Diff file")
            end,
        },
    },
}
