# Project plan: abl-tmux

## Purpose

An alternative to VS Code (with the vscode-abl extension) for editing OpenEdge ABL: nvim, Claude Code
and a bash terminal in one tmux window. It opens existing VS Code ABL workspaces as they are, so the
two can be used side by side (not at the same time on the same workspace).

## Original steps

- **Initial setup:** a tmux setup, starting from `claude-tmux.sh`; a dedicated, lean nvim config
  (copy only what's useful from the current one); keys that feel familiar to VS Code users without
  alienating vi users.
- **ABL editing:** configuration for OpenEdge ABL as the main language, plus bash, Python and
  PowerShell. Reuse what the vscode-abl extension offers, its language server first.

## Achieved

| Version | What |
|---|---|
| setup | tmux layout (nvim, claude, terminal) on its own tmux server; dedicated nvim config with VS Code keys; bash, Python, PowerShell language servers |
| setup | ABL language server from the VS Code extension: hover, completion, definition, references, symbols, formatting, compile on save with errors as diagnostics |
| 0.1.0 | Opens existing VS Code workspaces unchanged: root detection, `$VSCODE_WS`, `abl.*` settings from VS Code, check for `openedge-project.json`/`APPL.env` |
| 0.1.0 | Shared install in `/opt/abl-tmux` (`deploy.sh`, per-user `install.sh`, versions, release notes) |
| 0.1.0 | `abl-tmux --connect` (fzf), `-c` clean close with leftover-server cleanup; server starts with the workspace and never outlives nvim |
| 0.1.0 | Problems panel, explorer reveal, build output left out of file search, cheat sheet at start |
| 0.1.0 | claude starts connected to nvim (`--ide`) with instructions for this setup (`claude/abl-tmux.md`) |
| 0.2.0 | Ctrl+click on a file name in the terminal or claude opens it in nvim |
| 0.3.0-beta.3 | Bundled tmux 3.7c and Neovim 0.12.6 (`fetch-tools.sh`), native packages as fallback |
| 0.3.0-beta.2 | Update notice: what's new and an offer to rerun `install.sh` after a deploy |
| 0.3.0-beta.1 | VS Code tasks (Ctrl+Alt+T) with filePicker inputs; terminal title `user@host workspace`; user guide (`:Guide`) |
| 0.3.0-beta.1 | WezTerm (CCE config, branch `clipboard-image-paste`): image paste into claude over SSH, tab shows the workspace |

Details per change: `RELEASE-NOTES.md`; test results and decisions: `setup-notes.md`.

## To do

### Open

- **Tasks and OpenEdge character UI:** ChUI needs at least 80x25 and reads the size only at startup;
  the terminal pane is smaller. Decide: run each task in its own tmux window (a tab in the status
  bar, full size; recommended) or zoom the terminal pane before every task.
- **Release 0.3.0:** 0.3.0-beta.3 is deployed (2026-10-18); release after the tasks/ChUI decision and user feedback.
- **WezTerm:** confirm Ctrl+Shift+click opens URLs inside abl-tmux; merge `clipboard-image-paste` into
  `master` of the WezTerm config.

### Suggested

- **ABL check for claude without VS Code:** claude's ABL instructions expect the `vscode-abl` MCP
  (`compile_abl`), which only runs inside VS Code. An MCP server (or claudecode.nvim tool) that asks
  nvim's language server to compile a file would give claude the same check here.
- **Highlighting:** nvim's regex syntax for Progress; tree-sitter-abl once it parses real code.
- **Debugger:** see the gaps below; needs a paid vscode-abl subscription.

## vscode-abl features not (yet) in abl-tmux

Compared with vscode-abl 1.37.8 (`riversidesoftware.openedge-abl-lsp`) and its companion extensions.
"Relevance" is a first guess for CCE's way of working; not everything needs to come over.

| Feature (VS Code) | Status in abl-tmux | Relevance | How it could be done |
|---|---|---|---|
| Syntax check / compile on save, diagnostics | done | high | |
| Hover, completion, definition, references, symbols, formatting | done | high | |
| Project config, profiles, runtimes (`openedge-project.json`, `abl.*` settings) | done (read from VS Code) | high | |
| Switch profile (`abl.project.switch.profile`), rebuild/reload project, change build mode | missing | medium | The extension's server commands, sent from nvim (`workspace/executeCommand`); needs investigating |
| Restart language server | done (`:lsp restart abl`) | | |
| Run current file: `_progres` / `_progres -b` (F2) | via tasks only | medium | A built-in task or key like VS Code's F2 |
| Debug: attach to `-debugReady` AVM or PASOE (legacy and PASOE debugger, `launch.json`) | missing | ? | nvim-dap with the extension's debug adapter (`abl-lsda.jar --debug-adapter`); paid feature since 1.32 |
| Debug with `_progres -b` (Ctrl+F2), debug listing line (Alt+L) | missing | ? | With the debugger |
| CABL code analysis (SonarLint ABL, separate extension) | missing | ? | The sonarlint-abl language server in nvim, if it runs outside VS Code |
| Preprocess, listing, debug listing, XREF / XML-XREF, assembly catalog | missing | medium | Custom requests to the language server; claude may want them too (the extension offers them as language-model tools) |
| Organize usings (Ctrl+Shift+U), upper/lower casing, expand keywords | missing | low–medium | Code actions or commands of the server, if exposed |
| ABL outline, class browser views | partly: symbols (Space f s) | low | |
| OpenEdge documentation view, doc version switch | hover only | low | `oemcp-local` gives claude the docs |
| AppBuilder, procedure editor, Data Dictionary, prowin | n/a | | GUI tools on Windows |
| Strip AppBuilder markup | missing | low | |
| Proenv terminal profile | equivalent: terminal pane with `APPL.env` sourced | | |
| Unit tests (ABLUnit, separate extension) | missing | ? | Test runner via tasks, or neotest |
| Speedscript (.w/.html for WebSpeed) | missing | low | |
| Language-model tools (compile, check syntax, xref, listing, preprocess) for Copilot/claude | missing | high for claude | See "ABL check for claude" above |
