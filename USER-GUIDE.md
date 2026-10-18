# abl-tmux user guide

abl-tmux opens a VS Code ABL workspace in one terminal window: nvim (the editor) at the top left,
Claude Code on the right and a bash terminal at the bottom. It uses the same language server,
project file and settings as VS Code, and changes nothing in the workspace.

```
+-------------------------+-----------+
| nvim                    | claude    |
|                         |           |
+-------------------------+           |
| terminal (bash)         |           |
+-------------------------+-----------+
```

## Getting started

### Once: install

```
/opt/abl-tmux/install.sh
```

This links `~/bin/abl-tmux` and installs the editor plugins for you. It doesn't touch your own nvim
or tmux setup. You need VS Code with the vscode-abl extension already set up on this server (abl-tmux
reuses its language server) and Claude Code. Use a terminal of at least 160 columns; WezTerm works well.

### Open a workspace

```
abl-tmux ~/workspaces/develop      # or: cd into it (or any folder below it) and run abl-tmux
abl-tmux --connect                 # pick a running session or a workspace with fzf
```

The first time, the editor shows a cheat sheet with the most used keys; `q` closes it, `Space ?`
brings it back. Running `abl-tmux` again for the same workspace returns to the running session.

### Move around

- **Alt+1 / Alt+2 / Alt+3:** editor / claude / terminal (AZERTY: Alt+& / Alt+é / Alt+").
- **Ctrl+J:** jump between editor and terminal. **Alt+Z:** maximize the current pane, again to restore.
- The mouse works: click a pane, drag a border, scroll.

### Edit (if you're new to vim)

nvim starts in *Normal mode*, where letters are commands. Press **i** to type and **Esc** to stop
typing. Most VS Code keys work in both modes: **Ctrl+S** saves, **Ctrl+Z** undoes, **Ctrl+C** copies a
selection, **Ctrl+/** comments. Select with **v** (characters) or **V** (lines), or with the mouse.

### Find and open files

**Ctrl+P** opens a file by name, **Ctrl+Shift+F** (or Space f g) searches in files, **Ctrl+B** shows
the file explorer. Open files appear as tabs at the top; Ctrl+PageUp/PageDown switches, Alt+W closes.

### Compile and fix errors

Saving an ABL file compiles it. Errors appear in the code (red `E` in the margin, message at the end of
the line). **F8** jumps to the next problem, **Space d** shows the full message, **Ctrl+Shift+M** opens
the problems panel.

### Work with claude

claude starts connected to the editor: it sees the open file and your selection, and its changes
show up in the editor. `Space c s` sends the selection to claude, `Space c b` the whole file.
Paste a screenshot with Ctrl+Alt+V (WezTerm).

### Close

Quit the editor with `:qa` (it refuses with unsaved changes; `:qa!` discards them), then run
`abl-tmux -c` in the terminal. Or close everything at once: `abl-tmux -c` quits the editor cleanly
itself. To leave everything running and come back later: **Alt+B d** (detach), then `abl-tmux` again.

## Reference

### The launcher: abl-tmux

| Command | What it does |
|---|---|
| `abl-tmux [dir]` | Open (or return to) the workspace for `dir` (default: the current directory) |
| `abl-tmux file.code-workspace` | The same, for the workspace of that file |
| `abl-tmux --connect` | Pick with fzf: running sessions first, then folders under `~/workspaces` (or `$ABL_WORKSPACES`) with an `openedge-project.json` |
| `abl-tmux -l` | List running sessions |
| `abl-tmux -c [dir]` | Close cleanly: quit the editor (refuses with unsaved changes), close the session, stop leftover language servers |
| `abl-tmux -k [dir]` | Close the session without quitting the editor first |
| `abl-tmux -K` | Close all sessions |
| `abl-tmux -r [dir]` | Restart claude |
| `abl-tmux -V` | Show the installed version, and which tmux and nvim it uses |

- **Workspace root:** the nearest folder up from `dir` with an `openedge-project.json`, so you can start
  from any git project inside it. When the root has no `openedge-project.json` or `APPL.env`, abl-tmux
  asks before opening it.
- **`$VSCODE_WS`** is set to the root in every pane; the CCE shell setup then loads the workspace's
  `APPL.env` and changes to `$APPL`, as in VS Code's terminal.
- **One session per workspace,** named `abl-<folder>`; the terminal title shows `user@host workspace`.
- Start abl-tmux from a plain terminal, not from inside another tmux.
- **tmux and nvim versions:** abl-tmux brings recent tmux and Neovim builds along and uses those
  (`abl-tmux -V` shows them); inside a session, `tmux` and `nvim` in the terminal are those versions
  too. `ABL_TMUX_NATIVE=1 abl-tmux …` uses the server's own packages instead.

### Panes (tmux)

| Key | Action |
|---|---|
| Alt+1 / Alt+2 / Alt+3 (AZERTY: Alt+& / Alt+é / Alt+") | Focus editor / claude / terminal |
| Ctrl+J | Switch between editor and terminal (passes through in claude, where it's a new line) |
| Alt+Z | Maximize/restore the current pane |
| Ctrl+click on a file name in the terminal or claude | Open it in the editor; `file:line` and `file:line:col` jump to the line |
| Mouse | Click to focus, drag borders to resize, wheel to scroll |
| Ctrl+B | tmux prefix, except in the editor, where it toggles the explorer |
| Alt+B | tmux prefix everywhere; then `d` detaches, `b` sends a real Ctrl+B |

### Editor keys

| Key | Action |
|---|---|
| Ctrl+S | Save (ABL: compile) |
| Ctrl+P | Quick open file (Space f a: also hidden files and build output) |
| Ctrl+Shift+F or Space f g | Search in files |
| F1 or Ctrl+Shift+P | Command palette |
| Ctrl+Alt+T or `:Tasks` | Run a VS Code task (also from the terminal and claude panes) |
| Ctrl+B | Toggle the explorer |
| Ctrl+Alt+X or Space e | Reveal the current file in the explorer |
| Ctrl+PageUp/PageDown, Alt+W | Previous/next tab, close tab |
| Ctrl+/ | Toggle comment |
| Alt+Up/Down | Move line(s) |
| Shift+Alt+Up/Down | Duplicate line |
| Tab / Shift+Tab (selection) | Indent / outdent |
| Ctrl+Z, Ctrl+R | Undo, redo |
| Ctrl+C (selection) | Copy to the clipboard; paste with the terminal's paste key |
| Ctrl+G | Go to line |
| Alt+Left/Right | Go back/forward |
| F12, Ctrl+click | Go to definition |
| Shift+F12 | Find references |
| K | Hover information |
| F2 | Rename symbol |
| Ctrl+. or Space c a | Code action |
| Shift+Alt+F | Format document |
| Ctrl+Space, Tab/Enter | Completion: open, accept |
| F8 / Shift+F8 | Next/previous problem |
| Space d | Full message of the problem under the cursor |
| Ctrl+Shift+M or Space x x | Problems panel (Space x b: this file only); Enter jumps, q closes |
| Space ? | Cheat sheet |

More, under Space (press Space and wait for the list):

| Keys | Action |
|---|---|
| Space f … | Find: `f` files, `a` all files, `g` grep, `w` word under cursor, `b` open files, `r` recent files, `s` symbols in file, `k` all keys, `h` help, `d` problems |
| Space c … | claude: `b` add file, `s` send selection, `y`/`n` accept/reject a proposed change; code: `a` action, `f` format |
| Space g … | git: `p` preview change, `r` revert change, `b` line blame, `d` diff file |
| Space b d | Close tab |
| Space u n / u w | Toggle relative line numbers / word wrap |
| Space y | Copy to the clipboard |

Ctrl+Shift keys only work when the terminal sends them; each has a Space alternative. Vim keys work as
usual (Ctrl+A/F/D/W/V, `gd`, `grn`, `gra`, `grr`).

### ABL

- **Language server:** the Riverside server from your VS Code extension (`riversidesoftware.openedge-abl-lsp`,
  the newest copy under `~/.vscode-server/extensions`). It starts with the workspace, as in VS Code, and
  stops with the editor. `:lsp restart abl` restarts it, e.g. after changing settings.
- **Project and settings:** `openedge-project.json` as in VS Code (PROPATH, databases, profiles), and the
  `abl.*` settings from VS Code: the remote machine settings, the `.code-workspace` file, then
  `.vscode/settings.json` (runtimes, Java, extra Java arguments).
- **Features:** compile on save with errors as diagnostics, hover, completion, go to definition,
  references, symbols, formatting.
- **File types:** `.p .i .w .cls`. Highlighting is nvim's built-in Progress syntax.
- Use VS Code and abl-tmux on the same workspace one at a time: only one language server per project
  compiles.

### Problems

Errors and warnings show in the margin and at the end of the line. F8 / Shift+F8 step through them,
Space d shows the whole message, the problems panel (Ctrl+Shift+M) lists them per file. The list
covers the files the language server has reported on, mostly the ones you opened or saved.

### Files and search

Ctrl+P and search in files leave out build output: `.builder/`, `*.r` and the `buildDirectory` of
`openedge-project.json` (and its profiles). `Space f a` searches all files. The explorer (Ctrl+B) shows
git status per file.

### VS Code tasks

Ctrl+Alt+T lists the tasks of `.vscode/tasks.json` and the `.code-workspace` file, the last one run
first, and runs the chosen task in the terminal pane, typed as a visible command line (Ctrl+C stops it).

- A busy terminal isn't interrupted: the task isn't started.
- **Supported:** `shell` and `process` tasks with their `linux` section, `options.cwd` and `env`,
  `${workspaceFolder}`, `${file}` and the other file variables, `${env:…}`,
  `${command:abl.getDlcDirectory}` (`$DLC`), and `${input:…}` of type `promptString`, `pickString`
  and `filePicker.pick`.
- Tasks without a Linux command, or whose Linux command only says they are Windows-only, aren't listed.
- A task that runs `code <file>` opens the file in the editor.
- **Not supported:** `dependsOn`, problem matchers, other `${command:…}` variables.
- **OpenEdge character UI** needs at least 80x25 and reads the size at startup: tasks that ask for focus
  or run `_progres` get the terminal maximized first (Alt+Z restores).

### claude

- Starts with `--ide`: connected to the editor (open file, selection, proposed changes as diffs,
  diagnostics). If it isn't, type `/ide` in claude.
- Gets `claude/abl-tmux.md` with what this setup is and how to check ABL code here.
- `abl-tmux -r` restarts claude.

### WezTerm

With the CCE WezTerm config (github.com/ccecvb/wezterm-config, branch `clipboard-image-paste`):

- **Ctrl+Alt+V** pastes a clipboard image as a file path, e.g. into claude. On a server the image is
  copied to `~/.cache/wezterm-clip/` there first (removed after 7 days). Text pastes as usual.
- **Title:** the window shows `user@host workspace`, the tab just the workspace.
- **URLs:** tmux takes the mouse, so hold Shift too: Ctrl+Shift+click opens a URL. Shift+drag selects
  text in WezTerm itself.

### Other languages

bash, Python and PowerShell have language servers (bashls, pyright, powershell_es): completion,
hover, definition, problems.

## Updates

After an update of abl-tmux, the next `abl-tmux` shows what's new and asks to run `install.sh` again
(plugins and links); answer Enter. When sessions from the older version are still running, it says so:
close them with `abl-tmux -c` in each workspace, then `abl-tmux -K`, and start again. `abl-tmux -V`
shows the version; the full list of changes is in `RELEASE-NOTES.md` next to it.

## Troubleshooting

| Problem | What to do |
|---|---|
| No compile errors appear, or "Project already started in another window" in `:LspLog` | Another language server holds the project: close VS Code on that workspace, or run `abl-tmux -c` to stop leftover servers |
| claude doesn't see the editor | Type `/ide` in claude |
| A key does nothing | Some keys (Ctrl+Shift+…) depend on the terminal; use the Space alternative. `Space f k` lists all keys |
| The editor didn't pick up a file claude changed | Click into the editor or switch to the file; it reloads when you return to it |
| Language server log | `:LspLog` in the editor |
