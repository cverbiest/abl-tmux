-- Language servers for bash, python and pwsh, installed by mason.
-- vim defaults stay available: K hover, grn rename, gra actions, grr references.
return {
    {
        "mason-org/mason-lspconfig.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
        },
        opts = {
            ensure_installed = { "bashls", "pyright", "powershell_es", "lua_ls" },
        },
        config = function(_, opts)
            vim.lsp.config("lua_ls", {
                settings = { Lua = { workspace = { library = vim.api.nvim_get_runtime_file("", true) } } },
            })
            require("mason-lspconfig").setup(opts) -- also enables the installed servers

            vim.diagnostic.config({
                severity_sort = true,
                float = { border = "rounded", source = true },
                virtual_text = { spacing = 2 },
            })

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("abl_lsp", { clear = true }),
                callback = function(e)
                    local function map(mode, lhs, rhs, desc)
                        vim.keymap.set(mode, lhs, rhs, { buffer = e.buf, desc = desc })
                    end
                    local refs = function() require("telescope.builtin").lsp_references() end
                    map("n", "<F12>", vim.lsp.buf.definition, "Go to definition")
                    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
                    map("n", "<S-F12>", refs, "Find references")
                    map("n", "<F24>", refs, "Find references")
                    map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
                    map({ "n", "x" }, "<C-.>", vim.lsp.buf.code_action, "Quick fix")
                    map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
                    map("i", "<C-S-Space>", vim.lsp.buf.signature_help, "Signature help")                end,
            })
        end,
    },

    -- Format document (Shift+Alt+F); falls back to the language server's formatter
    {
        "stevearc/conform.nvim",
        cmd = "ConformInfo",
        keys = {
            { "<M-F>", function() require("conform").format({ lsp_format = "fallback" }) end,
                mode = { "n", "x" }, desc = "Format document" },
            { "<leader>cf", function() require("conform").format({ lsp_format = "fallback" }) end,
                mode = { "n", "x" }, desc = "Format document" },
        },
        opts = {},
    },
}
