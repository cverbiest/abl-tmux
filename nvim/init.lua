-- nvim config for the ABL tmux setup, loaded with NVIM_APPNAME=nvim-abl
-- (~/.config/nvim-abl is a symlink to this directory).

-- The nvim snap sets $HOME to a nonexistent /home/user; restore the real
-- one so "~" paths (claudecode's ~/.claude/ide lock files) resolve.
if vim.env.SNAP_REAL_HOME then
    vim.env.HOME = vim.env.SNAP_REAL_HOME
end

-- abl-tmux sets $ABL_NVIM_SOCKET: listen there too, so Ctrl+click on a file name in the
-- other panes opens it here (tmux/abl-open.sh). The first nvim in the session gets it;
-- a socket left by a crashed nvim (nothing answers) is taken over.
local sock = vim.env.ABL_NVIM_SOCKET
if sock and sock ~= "" and not pcall(vim.fn.serverstart, sock) then
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock, { rpc = true })
    if ok and chan > 0 then
        vim.fn.chanclose(chan)
    else
        os.remove(sock)
        pcall(vim.fn.serverstart, sock)
    end
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("abl.options")
require("abl.keymaps")
require("abl.autocmds")
require("abl.lazy")
require("abl.abl")
require("abl.cheatsheet")
require("abl.tasks")
