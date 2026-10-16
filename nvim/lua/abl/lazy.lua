local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable",
        "https://github.com/folke/lazy.nvim.git", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- lazy-lock.json pins the plugin versions. Users who can't write the shared config get
-- their own copy in their data dir, refreshed whenever the shared one changes.
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
if not vim.uv.fs_access(vim.fn.stdpath("config"), "W") then
    local own = vim.fn.stdpath("data") .. "/lazy-lock.json"
    local shared, mine = vim.uv.fs_stat(lockfile), vim.uv.fs_stat(own)
    if shared and (not mine or mine.mtime.sec < shared.mtime.sec) then
        vim.fn.mkdir(vim.fn.stdpath("data"), "p")
        vim.uv.fs_copyfile(lockfile, own)
        vim.uv.fs_chmod(own, tonumber("644", 8))
    end
    lockfile = own
end

require("lazy").setup({
    spec = { import = "abl.plugins" },
    install = { colorscheme = { "rose-pine" } },
    change_detection = { notify = false },
    rocks = { enabled = false },
    lockfile = lockfile,
})
