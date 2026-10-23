-- The ABL language server's state in the statusline, like VS Code's status bar item:
-- starting, project init, pending tasks (compiles), or not running. The server sends
-- "proparse/status" every ~9 s and when its task count changes.

local last, seen, from = nil, 0, nil -- last status, when, from which client id
local ever = false                   -- an abl client ran in this nvim

local function text()
    local client = vim.lsp.get_clients({ name = "abl" })[1]
    if not client then return ever and "ABL ✗ not running" or "" end
    ever = true
    if not last or from ~= client.id then return "ABL starting…" end
    if os.time() - seen > 20 then return "ABL ✗ no status" end
    local total, ready = #(last.projects or {}), last.numInitializedProjects or 0
    if total == 0 then return "ABL no project" end
    if ready < total then return ("ABL init %d/%d"):format(ready, total) end
    local warn = false
    for _, p in ipairs(last.projectDetails or {}) do
        if p.severity == "warning" then warn = true end
    end
    local tasks = last.pendingTasks or 0
    return (warn and "ABL ⚠ " or "ABL ") .. (tasks > 0 and ("◐ %d task(s)"):format(tasks) or "✓")
end

local function update()
    local t = text()
    if vim.g.abl_status ~= t then
        vim.g.abl_status = t
        vim.cmd.redrawstatus({ bang = true })
    end
end

-- Global handler, not in vim.lsp.config("abl"): ":lsp restart" starts the new client
-- with the old client's config
vim.lsp.handlers["proparse/status"] = function(_, result, ctx)
    last, seen, from = result, os.time(), ctx.client_id
    update()
end

vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = vim.api.nvim_create_augroup("abl_status", { clear = true }),
    callback = function() vim.schedule(update) end,
})

-- Also without a notification, so a silent server turns into "no status"
vim.uv.new_timer():start(1000, 2000, vim.schedule_wrap(update))

vim.api.nvim_create_user_command("AblDumpStatus", function()
    for _, c in ipairs(vim.lsp.get_clients({ name = "abl" })) do
        c:notify("proparse/dumpStatus", {})
    end
end, { desc = "Write the ABL language server's state to :LspLog" })

-- In the default statusline, right-aligned before the ruler
vim.g.abl_status = ""
vim.o.statusline = vim.o.statusline:gsub("%%=", "%%=%%{get(g:,'abl_status','')} ", 1)
