# ABL editing in nvim + claude + tmux

A VS Code-like setup: nvim (editor), Claude Code and a bash terminal in one tmux window.

```
/opt/abl-tmux/install.sh   # once per user: links the configs, installs nvim plugins
abl-tmux [dir]      # open (or re-attach to) the workspace for dir
abl-tmux --connect  # pick a running session or a workspace under ~/workspaces with fzf
abl-tmux -c [dir]   # close the workspace properly (see below)
```

`--connect` lists the running sessions first, then every directory directly under `~/workspaces`
(or `$ABL_WORKSPACES`) with an `openedge-project.json` that has no session yet.

It opens an existing VS Code ABL workspace as it is; nothing in the workspace needs to change.
`dir` may be the workspace root, any directory below it (e.g. one of the git projects) or its
`.code-workspace` file: the root is the nearest directory up with an `openedge-project.json`.
Every pane gets the root as `$VSCODE_WS`. When the root lacks `openedge-project.json` or `APPL.env`,
`abl-tmux` warns and asks before opening it (no answer means no).

Close a workspace with `abl-tmux -c [dir]`: it quits nvim (refusing while it has unsaved changes), so
nvim stops its ABL language server, closes the session, and stops leftover language servers of yours
whose nvim is gone (they hold the project, so a new server won't compile). `abl-tmux -c` outside
any session only does that cleanup. Alt+B d detaches and leaves everything running.

## Installing and updating

This is a git repo. `./deploy.sh [target]` copies what users need to `/opt/abl-tmux` (or `target`)
and writes the version (`git describe`) to `VERSION`; run it again to update, with sudo when the
target isn't writable for you. It only writes into a new directory or an earlier copy, and says when
the plugins changed. Changes are listed in `RELEASE-NOTES.md`; `abl-tmux -V` shows the version.

Each user runs `/opt/abl-tmux/install.sh` once, and again when `deploy.sh` reports changed plugins.
Plugins install into their own `~/.local/share/nvim-abl`, at the versions in `nvim/lazy-lock.json`;
when they can't write the shared copy, lazy keeps their lockfile there too.

`openedge-project.json`, `src/` and `dump/` in the repo directory are a local test project, not in git.

| Path | What |
|---|---|
| `nvim/` | nvim config, linked as `~/.config/nvim-abl` and used via `NVIM_APPNAME=nvim-abl`. Your normal `~/.config/nvim` is untouched. |
| `tmux/tmux.conf` | tmux config for a separate tmux server (`tmux -L abl`). `~/.tmux.conf` is untouched. |
| `nvim/cheatsheet.md` | Cheat sheet, shown when nvim starts without a file (Space ? reopens it). |
| `claude/abl-tmux.md` | Extra instructions for claude in the session. |
| `tmux/abl-tmux.sh` | Launcher, linked as `~/bin/abl-tmux`. Run `abl-tmux -h` for options (list, kill, reload claude). |
| `deploy.sh`, `RELEASE-NOTES.md` | Copy to `/opt/abl-tmux`; what changed per version. |

Start it from a plain terminal, not from inside another tmux: the outer tmux would catch Ctrl+B.
claude starts with `--ide`, so it connects to nvim (open files, selections, diffs, diagnostics) by
itself; type `/ide` if it didn't. It also gets `claude/abl-tmux.md` (`--append-system-prompt-file`):
what this setup is and how to check ABL code with the diagnostics.

## Keys

### tmux (panes)

| Key | Action |
|---|---|
| Alt+1 / Alt+2 / Alt+3 (AZERTY: Alt+& / Alt+é / Alt+") | Focus editor / claude / terminal |
| Ctrl+J | Switch between editor and terminal (passes through in claude) |
| Alt+Z | Maximize/restore the current pane |
| Ctrl+Click on a file name (`file`, `file:line`) in the terminal or claude | Open it in nvim (URLs keep working as before) |
| Mouse | Click to focus, drag borders to resize, wheel to scroll |
| Ctrl+B | tmux prefix, except in nvim, where it toggles the explorer |
| Alt+B | tmux prefix everywhere |

### nvim: VS Code keys

| Key | Action |
|---|---|
| Ctrl+S | Save |
| Ctrl+P | Quick open file (without build output; Space f a: all files) |
| F1 (or Ctrl+Shift+P) | Command palette |
| Ctrl+Shift+F or Space f g | Search in files |
| Ctrl+B | Toggle explorer |
| Ctrl+Alt+X or Space e | Reveal the current file in the explorer |
| Ctrl+/ | Toggle comment |
| Alt+Up/Down | Move line(s) |
| Shift+Alt+Up/Down | Duplicate line |
| Alt+Left/Right | Go back/forward |
| Tab / Shift+Tab (selection) | Indent / outdent |
| Ctrl+PageUp/PageDown, Alt+W | Previous/next buffer, close buffer |
| Ctrl+G | Go to line |
| Ctrl+Z | Undo |
| Ctrl+C (selection) | Copy to the system clipboard (OSC 52) |
| F12, Ctrl+Click | Go to definition |
| Shift+F12 | Find references |
| F2 | Rename symbol |
| Ctrl+. or Space c a | Code action |
| Shift+Alt+F | Format document |
| F8 / Shift+F8 | Next/previous problem |
| Ctrl+Shift+M or Space x x | Problems panel (Space x b: this file only); Enter jumps, q closes |
| Ctrl+Space, Tab/Enter | Completion: open, accept |

Ctrl+Shift combinations work only when the terminal sends them (extended keys).
Every one of them has a Space alternative.

Vim keys work as usual: Ctrl+A/F/D/W/V and the LSP defaults (`K`, `gd`, `grn`, `gra`, `grr`).
Press Space and wait to see all leader keys (which-key). `Space f k` lists every keybinding,
`Space ?` shows the cheat sheet.

Ctrl+P and search in files leave out build output: `.builder/`, `*.r` and the `buildDirectory`
of `openedge-project.json` and its profiles.

## Languages

bash, Python and PowerShell use mason-installed language servers (bashls, pyright, powershell_es).

ABL (`.p .i .w .cls`) uses the Riverside language server from the VS Code extension
(`riversidesoftware.openedge-abl-lsp`, newest copy under `~/.vscode*/extensions`, with its bundled JRE);
see `nvim/lua/abl/abl.lua`. As in VS Code, it starts when nvim opens in a workspace with an
`openedge-project.json` (as `abl-tmux` does), before any ABL file is opened. It gets the same `abl.*` settings as in VS Code: from
`~/.vscode-server/data/Machine/settings.json`, then the workspace's `.code-workspace` (`"settings"`),
then `.vscode/settings.json`. That covers the OpenEdge runtimes, `abl.langServerJavaExecutable` and
`abl.langServerExtraJavaArgs`; `:lsp restart abl` picks up changes. It reads `openedge-project.json` at the project root and compiles
the `"type": "source"` directories on save, so errors appear as diagnostics (F8). Hover, completion,
go to definition, references, symbols and formatting come from the same server.
When no settings list runtimes, `abl.lua` falls back to `/usr/oe122` and `/usr/oe128`.
Highlighting is nvim's built-in Progress syntax; tree-sitter-abl can't parse enough real code yet.
