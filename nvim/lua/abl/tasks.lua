-- VS Code tasks (Ctrl+Alt+T, :Tasks): pick a task from .vscode/tasks.json or the
-- .code-workspace "tasks", and run it in a task pane next to the terminal pane, reused as
-- presentation.panel says (outside tmux: in a terminal split). Supports shell/process tasks with their "linux"
-- overrides, options.cwd/env, the usual ${...} variables, ${command:abl.getDlcDirectory}
-- ($DLC) and ${input:...} (promptString, pickString, filePicker.pick). Tasks without a
-- Linux command are left out. A "code" command opens its files in nvim instead.
local vscode = require("abl.vscode")

local M = {}
-- The tmux of this session (abl-tmux may use its own, newer one)
local TMUX = vim.env.ABL_TMUX_BIN or "tmux"
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
    local pid = tonumber(vim.trim(vim.fn.system({ TMUX, "display-message", "-p", "-t", pane, "#{pane_pid}" })))
    local f = pid and io.open("/proc/" .. pid .. "/stat")
    if not f then return nil end
    local stat = f:read("*l")
    f:close()
    -- Fields after the command name: state ppid pgrp session tty_nr tpgid
    return pid, tonumber(stat:match("%) %S+ %S+ %S+ %S+ %S+ (%-?%d+)"))
end

local function tmux(...)
    return vim.trim(vim.fn.system({ TMUX, ... }))
end

-- What task_pane looks for: "shared", "dedicated:<label>" or "new"
local function panel_key(task)
    local panel = (task.presentation or {}).panel or "shared"
    return panel == "dedicated" and "dedicated:" .. task.label or panel
end

-- Task terminals, as in VS Code: tasks never run in the user's terminal pane but in a pane
-- of their own next to it, which presentation.panel decides on: "shared" (default) is one
-- pane reused by all tasks, "dedicated" one per task, "new" a new one each run. A pane is
-- reused once its task has ended (@abl_task_done); a busy one isn't interrupted.
-- Returns the pane to respawn (or nil for a new one), or nil, message when the task is
-- still running there.
-- Also returns any task pane, to split a new one from.
local function task_pane(task)
    local key = panel_key(task)
    local reuse, running, any
    for row in vim.gsplit(tmux("list-panes", "-F", "#{pane_id}\t#{@abl_task}\t#{@abl_task_done}\t#{@abl_task_label}"), "\n") do
        local id, k, done, label = unpack(vim.split(row, "\t"))
        if k ~= "" then any = id end
        if k == key and key ~= "new" and done == "1" then reuse = reuse or id end
        -- VS Code: a task that is still running is shown, not started twice
        if label == task.label and done == "0" then running = id end
    end
    if running then return nil, running end
    -- A busy shared terminal doesn't make another task wait: that one gets a new pane
    return reuse, nil, any
end

-- nvim's environment for the task (as VS Code tasks get VS Code's), without what belongs to
-- nvim or this pane
local function task_env()
    local args = {}
    local skip = { TMUX = true, TMUX_PANE = true, NVIM = true, VIM = true, VIMRUNTIME = true, MYVIMRC = true,
        NVIM_LOG_FILE = true }
    for k, v in pairs(vim.fn.environ()) do
        if not skip[k] and k:match("^[%w_]+$") then vim.list_extend(args, { "-e", k .. "=" .. v }) end
    end
    return args
end

-- The script the task pane runs: marks the pane as busy with this task, runs the command
-- line, marks it done, then VS Code's closing message
local function task_script(task, line)
    local p = task.presentation or {}
    local set = quote(TMUX) .. ' set-option -p -t "$TMUX_PANE" '
    local s = {
        set .. "@abl_task " .. quote(panel_key(task)) .. "; " .. set .. "@abl_task_label " .. quote(task.label)
            .. "; " .. set .. "@abl_task_done 0",
        quote(TMUX) .. ' select-pane -t "$TMUX_PANE" -T ' .. quote("Task: " .. task.label),
    }
    if p.clear then s[#s + 1] = "clear" end
    if p.echo ~= false then
        s[#s + 1] = "printf '\\e[2m * Executing task: %s\\e[0m\\n\\n' " .. quote(line)
    end
    s[#s + 1] = "bash -c " .. quote(line) .. "; rc=$?"
    s[#s + 1] = set .. "@abl_task_done 1"
    if p.close then return table.concat(s, "\n") end
    s[#s + 1] = "printf '\\n\\e[2m * The task ended (exit %d). Press any key to close the terminal.\\e[0m' $rc"
    s[#s + 1] = "read -rsn1"
    return table.concat(s, "\n")
end

-- OpenEdge character UI needs at least 80x25: tasks that run it interactively, or ask for
-- focus (e.g. a script that starts it), get the terminal pane zoomed when it is smaller
local function wants_screen(task, line)
    if (task.presentation or {}).focus then return true end
    return (line:match("_progres") or line:match("%f[%w]m?pro%f[%W]")) and not line:match("%s%-b%f[%s%z]")
end

local function zoom_for_chui(pane)
    local function get(fmt)
        return vim.trim(vim.fn.system({ TMUX, "display-message", "-p", "-t", pane, fmt }))
    end
    if tonumber(get("#{pane_width}")) >= 80 and tonumber(get("#{pane_height}")) >= 25 then return end
    if get("#{window_zoomed_flag}") ~= "1" then vim.fn.system({ TMUX, "resize-pane", "-Z", "-t", pane }) end
    if tonumber(get("#{window_width}")) < 80 or tonumber(get("#{window_height}")) < 25 then
        vim.notify("The terminal is smaller than 80x25, too small for OpenEdge character UI", vim.log.levels.WARN)
    end
end

-- Scripts may start the character UI themselves: for the first minute of a task, zoom
-- the pane as soon as a _progres runs in it (the pane's processes share its session)
local function watch_for_chui(pane)
    local timer, ticks = vim.uv.new_timer(), 0
    local function stop() timer:stop() timer:close() end
    timer:start(300, 300, vim.schedule_wrap(function()
        ticks = ticks + 1
        local pid = foreground(pane)
        if not pid or ticks > 200 or tmux("display-message", "-p", "-t", pane, "#{@abl_task_done}") == "1" then
            return stop()
        end
        vim.fn.system({ "pgrep", "-s", tostring(pid), "-x", "_progres" })
        if vim.v.shell_error == 0 then
            zoom_for_chui(pane)
            stop()
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
    local reuse, running, other = task_pane(task)
    if running then
        vim.fn.system({ TMUX, "select-pane", "-t", running })
        return vim.notify("Task " .. task.label .. " is still running (Ctrl+C stops it)", vim.log.levels.INFO)
    end
    -- options.cwd is in the command line (cd); relative paths are from the workspace folder
    local cmd = vim.list_extend({ "-c", dir }, task_env())
    vim.list_extend(cmd, { "bash", "-c", task_script(task, line) })
    local pane
    if reuse then
        tmux("set-option", "-p", "-t", reuse, "@abl_task_done", "0")
        vim.fn.system(vim.list_extend({ TMUX, "respawn-pane", "-k", "-t", reuse }, cmd))
        pane = reuse
    else
        -- Next to the terminal pane, like a terminal tab in VS Code's panel; more task panes
        -- share the space of the first, the terminal keeps its half
        local shell = tmux("display-message", "-p", "#{@shell_pane}")
        local target = other or (shell ~= "" and shell or nil)
        local where = target and { "-h", "-t", target } or { "-v", "-l", "20%" }
        pane = tmux(unpack(vim.list_extend(vim.list_extend({ "split-window", "-d", "-P", "-F", "#{pane_id}" }, where), cmd)))
        if vim.v.shell_error ~= 0 then return vim.notify("Task " .. task.label .. ": " .. pane, vim.log.levels.WARN) end
    end
    if wants_screen(task, line) then
        vim.fn.system({ TMUX, "select-pane", "-t", pane })
        zoom_for_chui(pane)
    end
    watch_for_chui(pane)
    if (task.presentation or {}).focus then vim.fn.system({ TMUX, "select-pane", "-t", pane }) end
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
