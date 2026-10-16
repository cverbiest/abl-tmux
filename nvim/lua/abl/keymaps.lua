-- VS Code style keys on top of the vim defaults. Plain vim keys (C-a, C-f, C-d,
-- C-w, C-v, ...) are left alone so vi users keep their muscle memory.
-- Plugin keys (C-p, C-b, F12, ...) live in the plugin specs.
local map = vim.keymap.set

map({ "n", "i", "x" }, "<C-s>", "<cmd>update<cr>", { desc = "Save file" })
map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { desc = "Clear search highlight" })

-- Undo: C-z would only suspend nvim inside tmux
map({ "n", "i" }, "<C-z>", "<cmd>undo<cr>", { desc = "Undo" })

-- Copy selection to the system clipboard
map("x", "<C-c>", '"+y', { desc = "Copy to clipboard" })
map({ "n", "x" }, "<leader>y", '"+y', { desc = "Yank to clipboard" })

-- Toggle comment (terminals send C-/ as C-_)
for _, key in ipairs({ "<C-/>", "<C-_>" }) do
    map("n", key, "gcc", { remap = true, desc = "Toggle comment" })
    map("x", key, "gc", { remap = true, desc = "Toggle comment" })
    map("i", key, "<cmd>normal gcc<cr>", { desc = "Toggle comment" })
end

-- Alt+Up/Down moves lines, Shift+Alt+Up/Down duplicates them
map("n", "<M-Up>", "<cmd>move .-2<cr>==", { desc = "Move line up" })
map("n", "<M-Down>", "<cmd>move .+1<cr>==", { desc = "Move line down" })
map("i", "<M-Up>", "<Esc><cmd>move .-2<cr>==gi", { desc = "Move line up" })
map("i", "<M-Down>", "<Esc><cmd>move .+1<cr>==gi", { desc = "Move line down" })
map("x", "<M-Up>", ":move '<-2<cr>gv=gv", { silent = true, desc = "Move selection up" })
map("x", "<M-Down>", ":move '>+1<cr>gv=gv", { silent = true, desc = "Move selection down" })
map("n", "<M-S-Up>", "<cmd>copy .-1<cr>", { desc = "Duplicate line up" })
map("n", "<M-S-Down>", "<cmd>copy .<cr>", { desc = "Duplicate line down" })

-- Alt+Left/Right: back/forward through the jump list
map("n", "<M-Left>", "<C-o>", { desc = "Go back" })
map("n", "<M-Right>", "<C-i>", { desc = "Go forward" })

-- Indent selection, keeping it selected
map("x", "<Tab>", ">gv", { desc = "Indent" })
map("x", "<S-Tab>", "<gv", { desc = "Outdent" })
map("x", ">", ">gv")
map("x", "<", "<gv")

-- Buffers (shown as tabs by bufferline)
map("n", "<C-PageDown>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<C-PageUp>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<M-w>", "<cmd>bdelete<cr>", { desc = "Close buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })

map("n", "<C-g>", ":", { desc = "Go to line (type the number)" })

-- Diagnostics: F8 / Shift+F8 (terminals often send Shift+F8 as F20)
local function diag(count)
    return function() vim.diagnostic.jump({ count = count, float = true }) end
end
map("n", "<F8>", diag(1), { desc = "Next problem" })
map("n", "<S-F8>", diag(-1), { desc = "Previous problem" })
map("n", "<F20>", diag(-1), { desc = "Previous problem" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show problem under cursor" })

map("n", "<leader>un", function() vim.wo.relativenumber = not vim.wo.relativenumber end,
    { desc = "Toggle relative numbers" })
map("n", "<leader>uw", function() vim.wo.wrap = not vim.wo.wrap end, { desc = "Toggle word wrap" })
