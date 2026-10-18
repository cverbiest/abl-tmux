-- Cheat sheet (cheatsheet.md next to init.lua), shown like VS Code's welcome page when
-- nvim starts without files. Space ? (or :Cheatsheet) reopens it, q closes it.
local path = vim.fn.stdpath("config") .. "/cheatsheet.md"

local function open()
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.bo.modifiable = false
    vim.bo.readonly = true
    vim.keymap.set("n", "q", "<cmd>bdelete<cr>", { buffer = true, desc = "Close cheat sheet" })
end

vim.api.nvim_create_user_command("Cheatsheet", open, { desc = "Show the abl-tmux cheat sheet" })
-- The full user guide, next to nvim/ in the abl-tmux folder (the config dir is a link to nvim/)
vim.api.nvim_create_user_command("Guide", function()
    vim.cmd.edit(vim.fn.fnameescape(vim.fs.dirname(vim.fn.resolve(vim.fn.stdpath("config"))) .. "/USER-GUIDE.md"))
    vim.bo.modifiable = false
    vim.bo.readonly = true
end, { desc = "Show the abl-tmux user guide" })
vim.keymap.set("n", "<leader>?", open, { desc = "Cheat sheet" })

vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("abl_cheatsheet", { clear = true }),
    once = true,
    callback = function()
        -- Only on an empty start: no files, nothing piped in
        if vim.fn.argc() == 0 and vim.api.nvim_buf_get_name(0) == "" and vim.bo.buftype == ""
            and vim.api.nvim_buf_line_count(0) == 1 and vim.fn.getline(1) == "" then
            open()
        end
    end,
})
