# Release notes

Updating: an admin runs `deploy.sh` from the repo (it copies to `/opt/abl-tmux`). When it reports
that plugins changed, every user runs `/opt/abl-tmux/install.sh` again. Restart nvim in running
sessions, and `abl-tmux -r` to restart claude.

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
