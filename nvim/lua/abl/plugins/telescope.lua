-- Fuzzy finders: Quick Open, Command Palette, search across files
local function builtin(name, opts)
    return function() require("telescope.builtin")[name](opts) end
end

-- Workspace folder (with openedge-project.json) and the buildDirectory of the project and
-- its profiles, relative to the cwd
local function build_dirs()
    local cwd = vim.fn.getcwd()
    local root = vim.fs.root(cwd, "openedge-project.json")
    local f = root and io.open(root .. "/openedge-project.json")
    if not f then return root, {} end
    local ok, project = pcall(vim.json.decode, f:read("*a"), { skip_comments = true })
    f:close()
    if not ok or type(project) ~= "table" then return root, {} end
    local dirs, rels = { project.buildDirectory }, {}
    for _, profile in ipairs(project.profiles or {}) do
        dirs[#dirs + 1] = type(profile.value) == "table" and profile.value.buildDirectory or nil
    end
    for _, dir in pairs(dirs) do
        if type(dir) == "string" and dir ~= "" and dir ~= "." then
            local abs = dir:sub(1, 1) == "/" and dir or vim.fs.joinpath(root, dir)
            local rel = vim.fs.relpath(cwd, vim.fs.normalize(abs))
            if rel and rel ~= "." then rels[#rels + 1] = rel end
        end
    end
    return root, rels
end

-- Build output stays out of search in files: .builder/, r-code and the buildDirectory
-- (Lua patterns on paths relative to the cwd)
local function build_output_patterns()
    local patterns = { "^%.builder/", "%.r$" }
    for _, rel in ipairs(select(2, build_dirs())) do patterns[#patterns + 1] = "^" .. vim.pesc(rel) .. "/" end
    return patterns
end

-- Quick open: our own exclusions in gitignore syntax, not .gitignore (workspaces often
-- gitignore sources). Hidden files (.vscode/) are shown, like VS Code. The buildDirectory is
-- left out except _buildinfo/. .vscode/abl-tmux.ignore in the workspace adds rules (and wins).
local function find_files()
    local root, rels = build_dirs()
    local rules = { ".git/", ".builder/", "*.r" }
    for _, rel in ipairs(rels) do
        vim.list_extend(rules, { "/" .. rel .. "/*", "!/" .. rel .. "/_buildinfo/" })
    end
    local defaults = vim.fn.tempname()
    vim.fn.writefile(rules, defaults)
    local cmd = { "rg", "--files", "--color", "never", "--hidden", "--no-ignore", "--ignore-file", defaults }
    local custom = root and root .. "/.vscode/abl-tmux.ignore"
    if custom and vim.uv.fs_stat(custom) then vim.list_extend(cmd, { "--ignore-file", custom }) end
    require("telescope.builtin").find_files({ find_command = cmd, file_ignore_patterns = {} })
end

return {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<C-p>", find_files, desc = "Quick open file" },
        { "<F1>", builtin("commands"), desc = "Command palette" },
        { "<C-S-p>", builtin("commands"), desc = "Command palette" },
        { "<C-S-f>", builtin("live_grep"), desc = "Search in files" },
        { "<leader>ff", find_files, desc = "Files" },
        { "<leader>fa", builtin("find_files", { hidden = true, no_ignore = true, file_ignore_patterns = {} }),
            desc = "All files (hidden, ignored, build output)" },
        { "<leader>fg", builtin("live_grep"), desc = "Grep in files" },
        { "<leader>fw", builtin("grep_string"), desc = "Word under cursor" },
        { "<leader>fb", builtin("buffers"), desc = "Open buffers" },
        { "<leader>fr", builtin("oldfiles", { only_cwd = true }), desc = "Recent files" },
        { "<leader>fd", builtin("diagnostics"), desc = "Problems" },
        { "<leader>fs", builtin("lsp_document_symbols"), desc = "Symbols in file" },
        { "<leader>fk", builtin("keymaps"), desc = "Keybindings" },
        { "<leader>fh", builtin("help_tags"), desc = "Help" },
        { "<leader>/", builtin("current_buffer_fuzzy_find"), desc = "Search in buffer" },
    },
    opts = {
        defaults = {
            file_ignore_patterns = build_output_patterns(),
            layout_strategy = "flex",
            mappings = { i = { ["<Esc>"] = "close" } }, -- one Esc closes, like VS Code
        },
    },
}
