local opt = vim.opt

opt.number = true
opt.relativenumber = false -- VS Code style; toggle with <leader>un
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.wrap = false
opt.termguicolors = true
opt.mouse = "a"
opt.splitright = true
opt.splitbelow = true

opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true -- cleared with <Esc>

opt.swapfile = false
opt.undofile = true
opt.autoread = true -- pick up edits made by claude in the other pane
opt.updatetime = 250
opt.confirm = true -- ask to save instead of failing on :q with changes

-- Over ssh there is no X clipboard: copy to the "+" register via OSC 52
-- (tmux forwards it to the terminal). Reading the terminal clipboard is often
-- blocked, so "+" pastes the last yank; paste from the terminal (Ctrl+Shift+V).
if not vim.env.DISPLAY and not vim.env.WAYLAND_DISPLAY then
    local osc52 = require("vim.ui.clipboard.osc52")
    local function last_yank()
        return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') }
    end
    vim.g.clipboard = {
        name = "OSC 52",
        copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
        paste = { ["+"] = last_yank, ["*"] = last_yank },
    }
end
