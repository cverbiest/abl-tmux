-- VS Code tasks (Ctrl+Alt+T, :Tasks): pick a task from .vscode/tasks.json or the
-- .code-workspace "tasks", and run it in the terminal pane below, typed as a command line
-- (outside tmux: in a terminal split). Supports shell/process tasks with their "linux"
-- overrides, options.cwd/env, the usual ${...} variables, ${command:abl.getDlcDirectory}
-- ($DLC) and ${input:...} (promptString, pickString, filePicker.pick). Tasks without a
-- Linux command are left out. A "code" command opens its files in nvim instead.
local vscode = require("abl.vscode")

local M = {}
local last_label -- the last task run is listed first

local function root()
    return vim.fs.root(vim.fn.getcwd(), { "openedge-project.json", ".vscode" }) or vim.fn.getcwd()
end

-- Telescope list; calls on_choice(item) unless cancelled
local function pick(title, items, format, on_choice)
    local actions, state = require("telescope.actions"), require("telescope.actions.state")
    require("telescope.pickers").new({}, {
        prompt_title = title,
        finder = require("telescope.finders").new_table({
            results = items,
            entry_maker = function(item)
                local text = format(item)
                return { value = item, display = text, ordinal = text }
            end,
        }),
        sorter = require("telescope.config").values.generic_sorter({}),
        attach_mappings = function(bufnr)
            actions.select_default:replace(function()
                local entry = state.get_selected_entry()
                actions.close(bufnr)
                if entry then vim.schedule(function() on_choice(entry.value) end) end
            end)
            return true
        end,
    }):find()
end

-- Waits (inside a coroutine) for a picker or prompt; nil when cancelled
local function await(start)
    local co = coroutine.running()
    start(function(value) coroutine.resume(co, value) end)
    return coroutine.yield()
end

-- The task with its "linux" section applied, or nil when it has no Linux command
local function for_linux(task)
    local t = vim.deepcopy(task)
    for k, v in pairs(task.linux or {}) do
        if k == "options" then
            t.options = vim.tbl_deep_extend("force", t.options or {}, v)
        else
            t[k] = v
        end
    end
    local cmd = t.command
    if type(cmd) ~= "string" or cmd == "" or t.hide then return nil end
    -- A Linux command that only says the task is Windows-only
    if cmd:match("^echo .*[Ww]indows.only") then return nil end
    return t
end

local function load_tasks(dir)
    local tasks = {}
    local files = { dir .. "/.vscode/tasks.json" }
    local function add(list)
        for _, task in ipairs(list or {}) do
            local t = for_linux(task)
            if t then tasks[#tasks + 1] = t end
        end
    end
    local file = vscode.read(files[1])
    add(file.tasks)
    local inputs = vim.deepcopy(file.inputs or {})
    local ws = vscode.workspace_file(dir)
    if ws then
        local w = vscode.read(ws).tasks or {}
        add(w.tasks)
        vim.list_extend(inputs, w.inputs or {})
    end
    return tasks, inputs
end

-- Asks for the value of an ${input:id}; nil when cancelled or unsupported
local function ask(input, dir)
    if input.type == "promptString" then
        return await(function(done)
            vim.ui.input({ prompt = (input.description or input.id) .. ": ", default = input.default }, done)
        end)
    elseif input.type == "pickString" then
        return await(function(done)
            pick(input.description or input.id, input.options or {}, function(o)
                return type(o) == "table" and (o.label or o.value) or o
            end, function(o) done(type(o) == "table" and o.value or o) end)
        end)
    elseif input.type == "command" and input.command == "filePicker.pick" then
        local args = input.args or {}
        local files = vim.fn.glob(dir .. "/" .. (args.masks or "*"), false, true)
        local function as(kind, path)
            local rel = vim.fs.relpath(dir, path) or path
            if kind == "fileName" then return vim.fs.basename(path) end
            if kind == "dirRelativePath" then return vim.fs.dirname(rel) end
            if kind == "filePath" then return path end
            if kind == "dirPath" then return vim.fs.dirname(path) end
            return rel
        end
        local display = (args.display or {}).type or "fileRelativePath"
        return await(function(done)
            pick(input.id, files, function(f) return as(display, f) end,
                function(f) done(as(args.output or "fileRelativePath", f)) end)
        end)
    end
    vim.notify("Task input " .. input.id .. ": type " .. tostring(input.command or input.type) .. " isn't supported",
        vim.log.levels.WARN)
end

-- Replaces ${...}; values of ${input:...} come from `answers`. Returns nil, var on an unknown one.
local function expand(s, dir, file, answers)
    local unknown
    local out = s:gsub("%${([^}]+)}", function(var)
        local values = {
            workspaceFolder = dir, workspaceRoot = dir, workspaceFolderBasename = vim.fs.basename(dir),
            file = file, relativeFile = vim.fs.relpath(dir, file) or file,
            fileBasename = vim.fs.basename(file), fileDirname = vim.fs.dirname(file),
            fileBasenameNoExtension = vim.fn.fnamemodify(file, ":t:r"),
            fileExtname = vim.fn.fnamemodify(file, ":e") ~= "" and "." .. vim.fn.fnamemodify(file, ":e") or "",
            lineNumber = tostring(vim.fn.line(".")), cwd = vim.fn.getcwd(), userHome = vim.env.HOME,
            pathSeparator = "/", ["/"] = "/",
            ["command:abl.getDlcDirectory"] = vim.env.DLC or "/usr/dlc",
        }
        local v = values[var] or answers[var:match("^input:(.+)") or ""]
        if not v and var:match("^env:") then v = vim.env[var:sub(5)] or "" end
        if not v then unknown = unknown or var end
        return v
    end)
    if unknown then return nil, unknown end
    return out
end

local function quote(s)
    if s:match("^[%w%._/:=@%%+,-]+$") then return s end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- The pane's shell pid and its terminal's foreground process group. The shell is idle
-- when it is in the foreground itself (a task runs in a subshell, also named bash).
local function foreground(pane)
    local pid = tonumber(vim.trim(vim.fn.system({ "tmux", "display-message", "-p", "-t", pane, "#{pane_pid}" })))
    local f = pid and io.open("/proc/" .. pid .. "/stat")
    if not f then return nil end
    local stat = f:read("*l")
    f:close()
    -- Fields after the command name: state ppid pgrp session tty_nr tpgid
    return pid, tonumber(stat:match("%) %S+ %S+ %S+ %S+ %S+ (%-?%d+)"))
end

-- The terminal pane (abl-tmux's @shell_pane) if it is idle at a shell prompt
local function shell_pane()
    local pane = vim.trim(vim.fn.system({ "tmux", "display-message", "-p", "#{@shell_pane}" }))
    if vim.v.shell_error ~= 0 or pane == "" then return nil, "no terminal pane" end
    local pid, fg = foreground(pane)
    if pid and fg ~= pid then
        local cmd = vim.trim(vim.fn.system({ "tmux", "display-message", "-p", "-t", pane, "#{pane_current_command}" }))
        return nil, "the terminal is busy (" .. cmd .. "); stop it with Ctrl+C or wait"
    end
    return pane
end

-- OpenEdge character UI needs at least 80x25: tasks that run it interactively, or ask for
-- focus (e.g. a script that starts it), get the terminal pane zoomed when it is smaller
local function wants_screen(task, line)
    if (task.presentation or {}).focus then return true end
    return (line:match("_progres") or line:match("%f[%w]m?pro%f[%W]")) and not line:match("%s%-b%f[%s%z]")
end

local function zoom_for_chui(pane)
    local function get(fmt)
        return vim.trim(vim.fn.system({ "tmux", "display-message", "-p", "-t", pane, fmt }))
    end
    if tonumber(get("#{pane_width}")) >= 80 and tonumber(get("#{pane_height}")) >= 25 then return end
    if get("#{window_zoomed_flag}") ~= "1" then vim.fn.system({ "tmux", "resize-pane", "-Z", "-t", pane }) end
    if tonumber(get("#{window_width}")) < 80 or tonumber(get("#{window_height}")) < 25 then
        vim.notify("The terminal is smaller than 80x25, too small for OpenEdge character UI", vim.log.levels.WARN)
    end
end

-- Scripts may start the character UI themselves: for the first minute of a task, zoom
-- the pane as soon as a _progres runs in the foreground
local function watch_for_chui(pane)
    local timer, ticks = vim.uv.new_timer(), 0
    local function stop() timer:stop() timer:close() end
    timer:start(300, 300, vim.schedule_wrap(function()
        ticks = ticks + 1
        local pid, fg = foreground(pane)
        if not pid or ticks > 200 or (fg == pid and ticks > 3) then return stop() end
        if fg ~= pid then
            vim.fn.system({ "pgrep", "-g", tostring(fg), "-x", "_progres" })
            if vim.v.shell_error == 0 then
                zoom_for_chui(pane)
                stop()
            end
        end
    end))
end

local function run(task, inputs, dir, file)
    -- Ask each ${input:...} once, before expanding
    local answers = {}
    for id in vim.inspect(task):gmatch("%${input:([^}]+)}") do
        if not answers[id] then
            local input = vim.iter(inputs):find(function(i) return i.id == id end)
            if not input then return vim.notify("Task input " .. id .. " isn't defined", vim.log.levels.WARN) end
            answers[id] = ask(input, dir)
            if not answers[id] then return end
        end
    end
    local function x(s)
        local v, unknown = expand(s, dir, file, answers)
        if not v then error("${" .. unknown .. "} isn't supported", 0) end
        return v
    end
    local ok, line = pcall(function()
        local args = vim.tbl_map(function(a) return type(a) == "table" and a.value or a end, task.args or {})
        args = vim.tbl_map(x, args)
        local command = x(task.command)
        if command == "code" then -- VS Code opening files: open them here
            return { open = vim.tbl_filter(function(a) return not a:match("^%-") end, args) }
        end
        local parts = { task.type == "process" and quote(command) or command }
        for _, a in ipairs(args) do parts[#parts + 1] = quote(a) end
        local pre = {}
        local opts = task.options or {}
        if opts.cwd then pre[#pre + 1] = "cd " .. quote(x(opts.cwd)) end
        for k, v in pairs(opts.env or {}) do pre[#pre + 1] = "export " .. k .. "=" .. quote(x(v)) end
        local cmdline = table.concat(parts, " ")
        if #pre == 0 then return cmdline end
        return "( " .. table.concat(pre, " && ") .. " && " .. cmdline .. " )"
    end)
    if not ok then return vim.notify("Task " .. task.label .. ": " .. line, vim.log.levels.WARN) end
    last_label = task.label
    if type(line) == "table" then
        for _, f in ipairs(line.open) do vim.cmd.edit(vim.fn.fnameescape(f:sub(1, 1) == "/" and f or dir .. "/" .. f)) end
        return
    end

    if not vim.env.TMUX then
        vim.cmd("botright split | terminal " .. line)
        return
    end
    local pane, why = shell_pane()
    if not pane then return vim.notify("Task " .. task.label .. ": " .. why, vim.log.levels.WARN) end
    if wants_screen(task, line) then
        vim.fn.system({ "tmux", "select-pane", "-t", pane })
        zoom_for_chui(pane)
    end
    vim.fn.system({ "tmux", "send-keys", "-t", pane, "C-e", "C-u" })
    vim.fn.system({ "tmux", "send-keys", "-t", pane, "-l", line })
    vim.fn.system({ "tmux", "send-keys", "-t", pane, "Enter" })
    watch_for_chui(pane)
    if (task.presentation or {}).focus then vim.fn.system({ "tmux", "select-pane", "-t", pane }) end
end

function M.pick()
    local dir = root()
    local file = vim.api.nvim_buf_get_name(0)
    local tasks, inputs = load_tasks(dir)
    if #tasks == 0 then return vim.notify("No tasks in " .. dir .. "/.vscode/tasks.json", vim.log.levels.INFO) end
    for i, t in ipairs(tasks) do
        if t.label == last_label then table.insert(tasks, 1, table.remove(tasks, i)) break end
    end
    pick("Run task", tasks, function(t)
        return t.label .. (t.detail and ("  · " .. t.detail) or "")
    end, function(task)
        coroutine.wrap(run)(task, inputs, dir, file)
    end)
end

vim.api.nvim_create_user_command("Tasks", M.pick, { desc = "Run a VS Code task" })
vim.keymap.set("n", "<C-M-t>", M.pick, { desc = "Run task (VS Code tasks.json)" })

return M
