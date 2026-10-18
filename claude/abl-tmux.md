# abl-tmux session

This Claude session runs inside abl-tmux (`/opt/abl-tmux`), a tmux session with
three panes:
- top-left: Neovim (`NVIM_APPNAME=nvim-abl`) with the user's ABL files
- right: this Claude session
- bottom-left: a bash shell

The tmux session has its own socket (`tmux -L abl`). The pane ids are stored
in the window options `@editor_pane`, `@claude_pane` and `@shell_pane`.
`$VSCODE_WS` is the workspace root (the directory with `openedge-project.json`).

Images the user pastes with Ctrl+Alt+V (WezTerm) arrive as paths under
`~/.cache/wezterm-clip/`; read them as images.

## Neovim connection and ABL diagnostics
- Claude is started with `--ide` (and this file as `--append-system-prompt-file`)
  and connects to Neovim through the claudecode.nvim plugin. If the `mcp__ide__*`
  tools are missing, ask the user to type `/ide`.
- `mcp__ide__getDiagnostics` returns Neovim's diagnostics, only for files open in
  Neovim; asking for a file that isn't open fails with "File not open". The ABL
  errors (source "ABL Compiler") come from the Riverside OpenEdge ABL language server
  (`abl-lsda.jar` from the user's VS Code extension folder), started by Neovim's
  `abl` LSP client. It is the same language server that VS Code uses, with the
  same PROPATH and DB connections from `openedge-project.json`.
- Line numbers in the diagnostics are 0-based: add 1.
- The language server compiles a file when it is saved in Neovim and writes the
  `.r` to the project's `buildDirectory` (from `openedge-project.json`, often `tty/`).
  After an edit, still confirm the `.r` is newer than the source.
- Diagnostics reflect the editor buffer. Neovim has `autoread` on and reloads
  files changed on disk when the user returns to them, but a reload doesn't
  compile; only a save does. Until then the diagnostics can be stale, so ask the
  user to focus the buffer (or run `:e`) and save.
- When the `mcp__vscode-abl__*` MCP is not connected, use getDiagnostics plus
  the `.r` timestamp as the ABL check. Say that this is the check used.
