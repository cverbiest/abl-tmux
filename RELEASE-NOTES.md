# Release notes

Updating: an admin runs `deploy.sh` from the repo (it copies to `/opt/abl-tmux`). When it reports
that plugins changed, every user runs `/opt/abl-tmux/install.sh` again. Restart nvim in running
sessions, and `abl-tmux -r` to restart claude.

## Unreleased

- **No VS Code needed:** abl-tmux brings the vscode-abl language server along (newest stable from the
  Marketplace) and uses it when VS Code's copy is missing or older. `abl-tmux -V` shows which one.
- Neovim comes from the release tarball instead of the AppImage: no FUSE mount per nvim, nothing to
  clean up after a crash, works on hosts without FUSE.

## 0.3.0-beta.3 (2026-10-18)

- **Recent tmux and Neovim:** abl-tmux brings tmux 3.7c (was 3.2a on RHEL 9) and Neovim 0.12.6 along
  and uses them; `ABL_TMUX_NATIVE=1` uses the server's packages. Close running sessions
  (`abl-tmux -c` in each workspace, then `abl-tmux -K`) before the first start with the new tmux.

## 0.3.0-beta.2 (2026-10-18)

- **Update notice:** after a deploy, `abl-tmux` shows what's new and offers to run `install.sh`, and
  says when running sessions still use an older version.

## 0.3.0-beta.1 (2026-10-18)

Beta: VS Code tasks and the ChUI handling may still change (see `PROJECT-PLAN.md`).

- **VS Code tasks:** Ctrl+Alt+T (or `:Tasks`) picks a task from `.vscode/tasks.json` and runs it
  in the terminal pane, including the `filePicker` inputs. Windows-only tasks aren't listed.
- **User guide:** `USER-GUIDE.md` with getting started and all features (`:Guide` in nvim).
- **Terminal title:** `user@host workspace` (e.g. `user@hostname develop`) in the WezTerm
  tab and window title. Needs a new tmux server (`abl-tmux -K`, then `abl-tmux`).
- **WezTerm tips** in the user guide: Ctrl+Alt+V pastes a clipboard image as a file path (needs the
  `clipboard-image-paste` branch of the CCE WezTerm config); Ctrl+Shift+click opens URLs.
- claude knows where pasted images arrive (`claude/abl-tmux.md`).

## 0.2.0 (2026-10-17)

- **Ctrl+click on a file name** (`file`, `file:line`, `file:line:col`) in the terminal or claude pane
  opens it in nvim. URLs and other text behave as before; in nvim, Ctrl+click is still go to
  definition. Needs a new session (`abl-tmux -c`, then `abl-tmux`).

## 0.1.0 (2026-10-16)

First release for other users.

- **Workspace:** `abl-tmux [dir]` opens an existing VS Code ABL workspace as it is: nvim, claude and a
  terminal in one tmux window. It finds the workspace root from any subdirectory or `.code-workspace`
  file, sets `$VSCODE_WS` in every pane, and asks before opening a directory without
  `openedge-project.json` or `APPL.env`.
- **Sessions:** `abl-tmux --connect` picks a running session or a workspace under `~/workspaces` with
  fzf. `abl-tmux -c` closes a workspace cleanly and stops leftover language servers.
- **ABL language server:** the Riverside server from your VS Code extension, with the `abl.*` settings
  from VS Code (runtimes, Java). It starts with the workspace, as in VS Code, and compiles on save.
- **Problems panel:** Ctrl+Shift+M or Space x x (trouble.nvim), grouped per file.
- **Explorer:** Ctrl+B toggles it, Ctrl+Alt+X reveals the current file.
- **File search:** Ctrl+P and search in files leave out build output (`.builder/`, r-code, the
  `buildDirectory`); Space f a searches all files.
- **Cheat sheet:** opens when nvim starts without a file; Space ? reopens it.
- **claude:** starts connected to nvim (`--ide`) and knows about this setup (`claude/abl-tmux.md`).
