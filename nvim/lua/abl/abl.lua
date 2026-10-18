-- OpenEdge ABL: filetype and the Riverside language server from the vscode-abl
-- extension (riversidesoftware.openedge-abl-lsp), reused as-is from ~/.vscode-server.
-- The server gets the same "abl.*" settings as in VS Code, read from the workspace.

-- Used when no VS Code settings list OpenEdge installations (abl.configuration.runtimes)
local fallback_runtimes = {
    { name = "12.2", path = "/usr/oe122" },
    { name = "12.8", path = "/usr/oe128" },
}

-- nvim maps .p/.i to "progress", .w to "cweb" and .cls to "st"
vim.filetype.add({
    extension = { p = "abl", i = "abl", w = "abl", cls = "abl" },
})

-- Newest installed copy of the extension
local function extension_dir()
    local dirs = vim.fn.glob(vim.env.HOME .. "/.vscode*/extensions/riversidesoftware.openedge-abl-lsp-*", false, true)
    dirs = vim.tbl_filter(function(d) return not d:find("%-bad/") end, dirs)
    table.sort(dirs, function(a, b)
        return vim.version.lt(a:match("lsp%-([%d.]+)"), b:match("lsp%-([%d.]+)"))
    end)
    return dirs[#dirs]
end

local ext = extension_dir()
if not ext then
    vim.notify("ABL language server not found (riversidesoftware.openedge-abl-lsp extension)", vim.log.levels.WARN)
    return
end

local vscode = require("abl.vscode")

-- "abl.*" settings as VS Code resolves them, later files winning: remote machine
-- settings, the .code-workspace "settings", the folder's .vscode/settings.json.
-- Returns the "abl" section as a tree, with ${workspaceFolder} etc. expanded.
local function abl_settings(root)
    local flat = {}
    local function add(settings)
        for key, value in pairs(settings or {}) do
            if key:match("^abl%.") then flat[key] = value end
        end
    end
    for _, path in ipairs(vim.fn.glob(vim.env.HOME .. "/.vscode*/data/Machine/settings.json", false, true)) do
        add(vscode.read(path))
    end
    if root then
        local ws = vscode.workspace_file(root)
        if ws then add(vscode.read(ws).settings) end
        add(vscode.read(root .. "/.vscode/settings.json"))
    end

    local function expand(value)
        if type(value) == "table" then
            for k, v in pairs(value) do value[k] = expand(v) end
        elseif type(value) == "string" then
            value = value:gsub("%${([%w_:]+)}", function(var)
                if var == "workspaceFolder" or var == "workspaceRoot" then return root end
                if var == "userHome" then return vim.env.HOME end
                local env = var:match("^env:(.+)")
                if env then return vim.env[env] or "" end
            end)
        end
        return value
    end

    local tree = {}
    for key, value in pairs(flat) do
        local path = vim.split(key, ".", { plain = true })
        local t = tree
        for n = 2, #path - 1 do
            if type(t[path[n]]) ~= "table" then t[path[n]] = {} end
            t = t[path[n]]
        end
        t[path[#path]] = expand(value)
    end
    return tree
end

-- Every server started, so quitting nvim can stop those still starting up too:
-- vim.lsp.get_clients() only lists a client once it has initialized
local servers = {}

vim.lsp.config("abl", {
    -- The server ignores the "exit" notification and keeps running (with its AVM), holding
    -- the project so the next server won't compile; terminate it once it has been sent.
    -- Java exits with 143 on SIGTERM; don't report that as a crash.
    cmd = function(dispatchers, config)
        local settings = abl_settings(config.root_dir)
        local java = settings.langServerJavaExecutable
        if not java or java == "" or vim.fn.executable(java) == 0 then java = ext .. "/jre/bin/java" end
        if vim.fn.executable(java) == 0 then java = "java" end
        local cmd = { java }
        vim.list_extend(cmd, vim.split(settings.langServerExtraJavaArgs or "", "%s+", { trimempty = true }))
        vim.list_extend(cmd, { "-jar", ext .. "/resources/abl-lsda.jar" })

        local terminated = false
        local on_exit = dispatchers.on_exit
        dispatchers = vim.tbl_extend("force", dispatchers, {
            on_exit = function(code, signal)
                on_exit(terminated and code == 143 and 0 or code, signal)
            end,
        })
        local rpc = vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.cmd_cwd, env = config.cmd_env })
        servers[#servers + 1] = rpc
        local notify, terminate = rpc.notify, rpc.terminate
        rpc.terminate = function()
            terminated = true
            terminate()
        end
        rpc.notify = function(method, ...)
            local sent = notify(method, ...)
            if method == "exit" then rpc.terminate() end
            return sent
        end
        return rpc
    end,
    filetypes = { "abl" },
    -- In order: the first ancestor with openedge-project.json, else the git repository
    root_markers = { "openedge-project.json", ".git" },
    -- What the extension sends: its "abl" settings section
    before_init = function(params, config)
        local abl = vim.tbl_deep_extend("force", {
            buildMode = 1,
            formatter = vim.empty_dict(),
            inlayHints = vim.empty_dict(),
        }, abl_settings(config.root_dir))
        abl.configuration = abl.configuration or {}
        if not abl.configuration.runtimes or #abl.configuration.runtimes == 0 then
            abl.configuration.runtimes = fallback_runtimes
        end
        params.initializationOptions = { abl = abl, user = vim.env.USER }
    end,
})
vim.lsp.enable("abl")

-- As in VS Code: start the server as soon as nvim opens a workspace with an
-- openedge-project.json, not only with the first ABL file. ABL files opened later
-- reuse it (same name and root).
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("abl_lsp_start", { clear = true }),
    once = true,
    callback = function()
        local root = vim.fs.root(vim.fn.getcwd(), "openedge-project.json")
        if not root then return end
        local config = vim.deepcopy(vim.lsp.config.abl)
        config.name, config.root_dir = "abl", root
        vim.lsp.start(config, { attach = false })
    end,
})

-- nvim exits without waiting for the shutdown above, so stop the server right away
vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("abl_lsp_exit", { clear = true }),
    callback = function()
        for _, rpc in ipairs(servers) do
            if not rpc.is_closing() then rpc.terminate() end
        end
    end,
})
