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

-- VS Code settings files are JSON with comments and trailing commas.
-- vim.json.decode skips the comments; drop the trailing commas first.
local function decode_jsonc(s)
    -- Index of the next token after whitespace and comments
    local function next_token(i)
        while true do
            i = s:match("^%s*()", i)
            if s:sub(i, i + 1) == "//" then
                i = (s:find("\n", i, true) or #s) + 1
            elseif s:sub(i, i + 1) == "/*" then
                i = (select(2, s:find("*/", i + 2, true)) or #s) + 1
            else
                return i
            end
        end
    end
    local parts, start, i = {}, 1, 1
    while true do
        local j = s:find('[",/]', i)
        if not j then break end
        local c = s:sub(j, j)
        if c == '"' then
            local k = j + 1
            repeat
                k = s:find('[\\"]', k)
                local escape = k and s:sub(k, k) == "\\"
                if escape then k = k + 2 end
            until not escape
            i = (k or #s) + 1
        elseif c == "/" then
            local pair = s:sub(j, j + 1)
            i = (pair == "//" or pair == "/*") and next_token(j) or j + 1
        else
            if s:sub(next_token(j + 1)):match("^[%]}]") then
                parts[#parts + 1] = s:sub(start, j - 1)
                start = j + 1
            end
            i = j + 1
        end
    end
    parts[#parts + 1] = s:sub(start)
    return vim.json.decode(table.concat(parts), { skip_comments = true })
end

local function read_settings(path)
    local f = io.open(path)
    if not f then return {} end
    local text = f:read("*a")
    f:close()
    local ok, data = pcall(decode_jsonc, text)
    if not ok or type(data) ~= "table" then
        vim.notify("ABL: can't read " .. path .. ": " .. tostring(data), vim.log.levels.WARN)
        return {}
    end
    return data
end

-- The workspace's .code-workspace: the only one in root, or the one named after it
local function workspace_file(root)
    local files = vim.fn.glob(root .. "/*.code-workspace", false, true)
    if #files <= 1 then return files[1] end
    local own = root .. "/" .. vim.fs.basename(root) .. ".code-workspace"
    return vim.uv.fs_stat(own) and own or nil
end

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
        add(read_settings(path))
    end
    if root then
        local ws = workspace_file(root)
        if ws then add(read_settings(ws).settings) end
        add(read_settings(root .. "/.vscode/settings.json"))
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
