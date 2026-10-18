# Initial setup: notes

The initial setup is in place and working. Run `abl-tmux` from a plain terminal, not from inside another tmux, in the directory you want to work in. It opens nvim at the top left, claude on the right and a bash terminal at the bottom.

Tested in a throwaway tmux session:
- The layout comes up correctly, and the pane keys (Ctrl+J, Alt+1/2/3, Alt+B) and the Ctrl+B pass-through work.
- The explorer opens.
- The language servers attach for bash (bashls), Python (pyright) and pwsh (powershell_es), with syntax highlighting.

Not tested in the real terminal yet. Shift+F8 and the Ctrl+Shift keys (Ctrl+Shift+P, Ctrl+Shift+F) depend on what the terminal sends. Each has a Space-key alternative.

## What was set up

- **It doesn't touch the current setup.** nvim reads its own config (`nvim/`, linked as `~/.config/nvim-abl`). tmux runs as a separate server (`tmux -L abl`) with its own `tmux/tmux.conf`. `~/.config/nvim`, `~/.tmux.conf` and `claude-tmux.sh` are unchanged.
- **Launcher `tmux/abl-tmux.sh`**, linked as `~/bin/abl-tmux`. A cut-down version of the nvim layout from `claude-tmux.sh`, with one session per directory. `-l` lists sessions, `-k` closes one, `-r` restarts claude.
- **Kept from the current config:** the snap `$HOME` fix, claudecode.nvim (claude connects to nvim with `/ide`), telescope, treesitter, mason/LSP, and the move-line and indent mappings. Left out: the colorscheme collection, Go/zig/PHP, the games, harpoon, dap and neotest.
- **New plugins (seven):** nvim-tree (file explorer), bufferline (open files as tabs), which-key, blink.cmp (completion), mini.pairs (auto-closing brackets), gitsigns and conform (formatting).
- **VS Code keys:** Ctrl+S, Ctrl+P, F1, Ctrl+B, Ctrl+/, Alt+Up/Down, F12, F2, F8 and Shift+Alt+F, among others. The full cheat sheet is in `README.md`.
- **Vi users:** Ctrl+A/F/D/W/V and the built-in LSP keys (`K`, `grn`, `gra`, `grr`) still do what they normally do.

## Choices worth checking

- **Ctrl+B:** the tmux prefix everywhere except inside nvim, where it toggles the explorer as in VS Code. Alt+B works as the prefix everywhere.
- **Ctrl+J:** switches between the editor and the terminal, like VS Code's panel toggle. In the claude pane it passes through, because claude uses it for a newline.
- **Alt+Up/Down** move lines as in VS Code, so moving between panes is on Alt+1/2/3, the mouse, or the tmux prefix.
- **Clipboard:** copying goes to the local clipboard through OSC 52. Paste with the terminal's own paste key.

## ABL editing: progress (2026-10-13)

### Done

- **Language server:** `nvim/lua/abl/abl.lua` reuses the Riverside server from the VS Code extension (`riversidesoftware.openedge-abl-lsp`, newest copy under `~/.vscode*/extensions`, with its bundled JRE). `.p .i .w .cls` are filetype `abl`. Hover, completion, go to definition, references, symbols and formatting work. Saving compiles the file and shows compile errors as diagnostics.
- **Highlighting:** nvim's built-in Progress regex syntax (`nvim/syntax/abl.lua`). tree-sitter-abl was dropped for now: a 231-line real file gave 31 parse errors. `nvim/ftplugin/abl.lua` sets `/* */` comments and adds `-` to `iskeyword`.
- **Fixes found along the way:**
  - `openedge-project.json`: `src` must be `"type": "source"`; with `"propath"` nothing gets compiled.
  - protermcap: `tmux-256color` added to the `xterm` entry in `/usr/oe128/protermcap`; without it the build AVM fails to start under tmux.
  - The server ignores LSP `exit` and keeps running with its AVM. A leftover server holds the project ("Project already started in another window, compilation will be handled there") and new ones don't compile. `abl.lua` now kills the server after `exit` (`:lsp restart abl`) and when nvim quits.

### Open

- **Error shown briefly, then cleared:** in the live session the server sent the compile errors and right after an empty diagnostics list for the same file. Not reproduced in a clean nvim (errors stay after repeated saves, also with a second nvim on the project that quits normally). Likely cause: that nvim was started before the exit fix, and leftover/orphaned servers held the project. Check after a clean restart; if it still happens, `:lua vim.lsp.log.set_level("debug")`, save once, and read `~/.local/state/nvim-abl/lsp.log`.
- **Leftover servers:** check with `ps -ef | grep abl-lsda`. One whose parent is gone (PPID 1) holds the project and must be killed. `abl-tmux -c` (2026-10-16) quits nvim cleanly, closes the session and kills this user's `java …/abl-lsda.jar` processes that have `NVIM_APPNAME=nvim-abl` and no nvim parent, with their `_progres` children. Tested with a real session, unsaved changes (refuses) and fake orphans. Seen: `-k` (SIGHUP) still lets nvim stop its server.
- `openedge-project.json`: `schemaFile` is now `dump/LISA.df` (untested). The `documentation` paths (`oe128/docs/*.json`) don't exist.
- Not started: reusing the extension's debugger (`abl-lsda.jar --debug-adapter`), running programs, ABLUnit tests.

### Logs

- `~/.local/state/nvim-abl/lsp.log` (`:LspLog`): server output; RPC traffic at debug level.
- `.builder/clientlog0.log`, `.builder/stdout0.log`: the build AVM.

## Other users (2026-10-16)

Goal: open any existing VS Code ABL workspace (root with `openedge-project.json`, ~26 git projects
directly under it and under `git/`, root itself not in git) without changing it. Assumed: every user
has a working VS Code Remote setup (extension under their own `~/.vscode-server`) and claude.

- **Done:** `abl.lua` reads the `abl.*` settings like VS Code (Machine settings, `.code-workspace` `"settings"`,
  `.vscode/settings.json`; JSONC; `${workspaceFolder}`/`${env:X}` expanded) and sends them as init options;
  Java comes from `abl.langServerJavaExecutable` when that exists. `abl-tmux` walks up to the
  `openedge-project.json` root, accepts a `.code-workspace` file and sets `$VSCODE_WS` in every pane;
  `ABL_TMUX_SOCKET` overrides the tmux socket for tests. Shared, read-only config: lazy keeps a per-user
  lockfile (`lazy.lua`); `install.sh` uses `Lazy! restore` and doesn't chmod files it doesn't own.
- **Tested:** settings of all workspaces in `~/cvb/workspaces` parse; JSONC edge cases; launch from a git
  subdirectory of a scratch workspace (root, `VSCODE_WS` in all panes, compile errors on save);
  restore with a read-only config.
- **Shared location:** `/opt/abl-tmux`, filled by `deploy.sh` (`$HOME` is mode 700). The protermcap
  `tmux-256color` entry in each OpenEdge install is the user's concern (CCE's own protermcap).
- **Server starts with the workspace** (2026-10-16): a `VimEnter` autocmd in `abl.lua` starts the ABL server
  (`vim.lsp.start`, `attach = false`) when nvim's cwd has an `openedge-project.json` up the tree; ABL files
  opened later reuse that client. Tested headless: one client before and after opening a `.p`, compile
  errors on save, no client outside a workspace.
- **Problems panel** (2026-10-16): trouble.nvim (`plugins/trouble.lua`) on Ctrl+Shift+M / Space x x, grouped per
  file like VS Code, plain characters instead of Nerd Font icons. Tested in a test tmux: two files, Enter jumps.
  Ctrl+Shift+M itself is untested (depends on the terminal sending extended keys).
- **claude instructions** (2026-10-16): `claude/abl-tmux.md` (drafted in another user's session, corrected here) is
  passed with `--append-system-prompt-file`; claude also starts with `--ide`. Tested: claude gets both arguments
  and connects to nvim without `/ide` (claudecode.nvim shows one connected client). Checked in claudecode.nvim:
  getDiagnostics lines are 0-based and need the file open in nvim.

## Git repo, deploy, cheat sheet (2026-10-16, v0.1.0)

- Git repo here; the test project (`openedge-project.json`, `src/`, `dump/`, `.builder/`, `tty/`) is ignored.
- `deploy.sh [target]` rsyncs the user files to `/opt/abl-tmux` (default), writes `VERSION` (git describe),
  refuses non-empty directories that aren't a copy, reports lockfile changes. Tested on scratch targets.
- Cheat sheet `nvim/cheatsheet.md`, opened on an empty start (`lua/abl/cheatsheet.lua`), Space ? / `:Cheatsheet`.
- Ctrl+P / grep skip `.builder/`, `*.r` and the `buildDirectory`s (telescope `file_ignore_patterns`); Space f a = all.
- **Fixed:** quitting nvim within ~3 s of starting left the ABL server running (orphan): `vim.lsp.get_clients()`
  doesn't list a client before it has initialized, so VimLeavePre missed it. `abl.lua` now tracks every
  server it starts. Tested: quit after 0.3–8 s, no orphans.
- **Ctrl+click opens files** (2026-10-17, unreleased): tmux `C-MouseDown1Pane` passes the click on (`send-keys -M`)
  and, outside the editor pane, runs `tmux/abl-open.sh` with `#{mouse_word}`; it opens existing files in nvim
  through `$ABL_NVIM_SOCKET` (nvim listens there, `init.lua`). Tested with SGR mouse sequences sent into a nested
  test client: file:line, quoted path, URL (ignored), missing file, nvim pane (click reaches nvim).
  Untested: whether the user's terminal still opens URLs itself (it decides before tmux sees the click).
- Note: `/etc/profile.d/vscode.sh` sources `$VSCODE_WS/APPL.env` and `cd $APPL` in every new shell pane;
  test workspaces need an `APPL.env` with `APPL=<dir>`, or the shells land in `$HOME`.

## WezTerm (2026-10-17)

The user's terminal is WezTerm on Windows (config: github.com/ccecvb/wezterm-config, CCE fork), servers are
WezTerm SSH domains from `~/.ssh/config`.

- **Image paste:** branch `clipboard-image-paste` (pushed, not merged): `utils/clip-paste.lua` on Ctrl+Alt+V,
  adapted from picton.uk's xclip/wl-paste version. PowerShell saves the clipboard image; on an SSH pane
  ssh/scp (BatchMode) copy it to `~/.cache/wezterm-clip/` on the host and the remote path is pasted.
  **Works** (2026-10-17, user on Windows): the screenshot arrived in `~/.cache/wezterm-clip/` and claude
  showed the pasted path as an image attachment (`[Image #1]`).
- **URLs:** the config's Ctrl+click → OpenLinkAtMouseCursor binding lacks `mouse_reporting = true`, so with
  tmux mouse on it never fires; Ctrl+Shift+click (Shift = WezTerm's mouse-reporting bypass) should. **Open:**
  user confirms.

## VS Code tasks (2026-10-17, unreleased)

`nvim/lua/abl/tasks.lua` on Ctrl+Alt+T (tmux forwards it from the other panes) and `:Tasks`. Runs the task
typed into the terminal pane, as `( cd … && export … && command args )`. JSONC reading moved from `abl.lua`
to `nvim/lua/abl/vscode.lua`. Tested in a test session with a copy of develop's tasks.json (10 of 11 listed;
"Lisa debug" left out: echo-only Linux command) and scratch tasks: quoting, cwd/env, `${fileBasename}`,
`$DLC`, filePicker + pickString inputs (same input asked once), `code -r` opening in nvim, busy terminal
refused, Ctrl+Alt+T from the terminal pane. Not tried: the real develop tasks (they start Lisa/PASOE).

## Bundled tmux and Neovim (2026-10-18, unreleased)

`fetch-tools.sh` → `tools/bin/tmux` (tmux/tmux-builds 3.7c, static) and `tools/bin/nvim` (AppImage 0.12.6;
FUSE is available, glibc 2.34 is enough, no LD_LIBRARY_PATH leaks to children). Launcher prefers them,
exports `ABL_TMUX_BIN`/`ABL_NVIM_BIN` and puts `tools/bin` first in PATH (survives the login scripts and
APPL.env in the panes), starts the editor with the full nvim path; tmux.conf run-shell uses `@abl_tmux`.
- A 3.7c client works with a 3.2a server; a 3.2a client against a 3.7c server fails ("server exited
  unexpectedly", the server survives). Hence the same binary everywhere inside a session.
- tmux 3.7 has a different default `word-separators` (splits on / . :), which broke Ctrl+click
  (`mouse_word` = "src"); tmux.conf now sets it explicitly.
- Tested (test session, bundled): versions, PATH in panes, title, Alt+1/2/3, Ctrl+J, Alt+Z, Ctrl+click,
  Ctrl+Alt+T task, compile on save, `abl-tmux -c`. Native fallback (`ABL_TMUX_NATIVE=1`): server 3.2a,
  snap nvim, keys, Ctrl+click.
