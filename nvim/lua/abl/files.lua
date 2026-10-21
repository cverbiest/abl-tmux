-- File names in the editor: gf and Ctrl+click open the file under the cursor.
-- 'path' gets the workspace folder and the directories of openedge-project.json's buildPath
-- (sources and PROPATH entries; not .pl/.apl archives), so names relative to the PROPATH
-- (RUN sub/x.p, {inc/defs.i}) resolve as well. ftplugin/abl.lua adds the ABL suffixes and
-- class names (A.B.C).
local vscode = require("abl.vscode")

local M = {}

-- ${VAR} and ${env:VAR} from the environment; DLC defaults to /usr/dlc
local function expand(s)
    return (s:gsub("%${([^}]+)}", function(var)
        var = var:gsub("^env:", "")
        return vim.env[var] or (var == "DLC" and "/usr/dlc") or ""
    end))
end

function M.set_path()
    local root = vim.fs.root(vim.fn.getcwd(), "openedge-project.json")
    if not root then return end
    local dirs = { root }
    for _, entry in ipairs(vscode.read(root .. "/openedge-project.json").buildPath or {}) do
        local dir = type(entry.path) == "string" and expand(entry.path) or ""
        if dir ~= "" then
            dir = dir:sub(1, 1) == "/" and dir or root .. "/" .. dir
            if vim.fn.isdirectory(dir) == 1 then dirs[#dirs + 1] = vim.fs.normalize(dir) end
        end
    end
    -- ".,," first: the current file's folder and the cwd, as by default
    vim.o.path = ".,," .. table.concat(vim.tbl_map(function(d)
        return (d:gsub("([, ])", "\\%1"))
    end, dirs), ",")
end

-- Looks like a file name rather than a word: has a folder or an extension
local function file_like(name)
    return name:find("/") or name:find("%.%w+$")
end

-- Opens the file named under the cursor (file:line jumps to the line, like gF);
-- false when there's no such file
function M.open_under_cursor()
    local name = vim.fn.expand("<cfile>")
    if name == "" or not file_like(name) then return false end
    return (pcall(vim.cmd, "normal! gF"))
end

-- Ctrl+click: the file under the mouse, else go to definition (language server)
function M.ctrl_click()
    if M.open_under_cursor() then return end
    if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/definition" }) > 0 then
        vim.lsp.buf.definition()
    end
end

M.set_path()
vim.api.nvim_create_autocmd("DirChanged", { callback = M.set_path, desc = "File search path from openedge-project.json" })
vim.keymap.set("n", "<C-LeftMouse>", "<LeftMouse><cmd>lua require('abl.files').ctrl_click()<cr>",
    { desc = "Open file / go to definition" })

return M
