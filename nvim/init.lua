-- nvim config for the ABL tmux setup, loaded with NVIM_APPNAME=nvim-abl
-- (~/.config/nvim-abl is a symlink to this directory).

-- The nvim snap sets $HOME to a nonexistent /home/user; restore the real
-- one so "~" paths (claudecode's ~/.claude/ide lock files) resolve.
if vim.env.SNAP_REAL_HOME then
    vim.env.HOME = vim.env.SNAP_REAL_HOME
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("abl.options")
require("abl.keymaps")
require("abl.autocmds")
require("abl.lazy")
require("abl.abl")
require("abl.cheatsheet")
