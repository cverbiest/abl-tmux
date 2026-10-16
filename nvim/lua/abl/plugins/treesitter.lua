-- nvim-treesitter `main` branch: installs parsers; highlighting is started per buffer.
-- ABL uses regex syntax instead (nvim/syntax/abl.lua).
return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
        require("nvim-treesitter").install({
            "bash", "python", "powershell", "lua", "vim", "vimdoc", "query",
            "json", "yaml", "markdown", "markdown_inline",
        })
        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("abl_treesitter", { clear = true }),
            callback = function(e)
                if pcall(vim.treesitter.start, e.buf) then
                    vim.bo[e.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end
            end,
        })
    end,
}
