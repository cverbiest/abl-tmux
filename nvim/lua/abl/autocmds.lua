local group = vim.api.nvim_create_augroup("abl", { clear = true })
local autocmd = vim.api.nvim_create_autocmd

autocmd("TextYankPost", {
    group = group,
    callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

-- Reload files changed outside nvim (e.g. by claude) when coming back to them
autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = group,
    callback = function()
        if vim.bo.buftype == "" then vim.cmd.checktime() end
    end,
})

-- Reopen files at the last cursor position
autocmd("BufReadPost", {
    group = group,
    callback = function(e)
        local mark = vim.api.nvim_buf_get_mark(e.buf, '"')
        if mark[1] > 1 and mark[1] <= vim.api.nvim_buf_line_count(e.buf) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})
