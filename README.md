# abl-tmux: ABL editing in nvim + claude + tmux

A VS Code-like setup for OpenEdge ABL: nvim (editor), Claude Code and a bash terminal in one tmux
window. It opens existing VS Code ABL workspaces as they are and reuses the vscode-abl language server.

- **Using it:** [USER-GUIDE.md](USER-GUIDE.md): getting started and all features (in nvim: `:Guide`).
- **What changed:** [RELEASE-NOTES.md](RELEASE-NOTES.md).
- **Plan, achievements, to do, gaps with vscode-abl:** [PROJECT-PLAN.md](PROJECT-PLAN.md).
- **Development notes and test results:** [setup-notes.md](setup-notes.md).

## Installing and updating (admin)

This is a git repo. `./fetch-tools.sh` downloads into `tools/` (not in git, about 250 MB):
the latest stable tmux (static build from github.com/tmux/tmux-builds) and Neovim (release tarball,
no FUSE needed), which the launcher and `install.sh` use instead of the native packages (unless
`ABL_TMUX_NATIVE=1`); and the vscode-abl extension from the VS Code Marketplace (newest stable,
`--pre-release` for the newest pre-release) for users without VS Code. nvim uses the newest of that
and the user's VS Code copy. Run it again to update, then deploy. `./deploy.sh [target]` copies what users need to `/opt/abl-tmux` (or `target`) and
writes the version (`git describe`) to `VERSION`; run it again to update, with sudo when the target
isn't writable for you. It only writes into a new directory or an earlier copy, copies `tools/` when
present, and says when the plugins changed.

Each user runs `/opt/abl-tmux/install.sh` once (`--no-cce` outside CCE: no `APPL.env` check or
CreateWorkspace offer; kept in `~/.config/abl-tmux/config` as `cce=0`). After a deploy, `abl-tmux` shows users what's new
(from `RELEASE-NOTES.md`) and offers to rerun `install.sh`; it compares the deployed `VERSION` with
the one `install.sh` recorded in `~/.local/state/abl-tmux/installed-version`.
Plugins install into their own `~/.local/share/nvim-abl`, at the versions in `nvim/lazy-lock.json`;
when they can't write the shared copy, lazy keeps their lockfile there too.

## Repository

| Path | What |
|---|---|
| `tmux/abl-tmux.sh` | Launcher, linked as `~/bin/abl-tmux` (`abl-tmux -h`) |
| `tmux/tmux.conf` | tmux config for a separate tmux server (`tmux -L abl`); `~/.tmux.conf` is untouched |
| `tmux/abl-open.sh` | Ctrl+click on a file name: open it in nvim |
| `nvim/` | nvim config, linked as `~/.config/nvim-abl` and used via `NVIM_APPNAME=nvim-abl`; `~/.config/nvim` is untouched |
| `nvim/lua/abl/abl.lua` | ABL file types and language server; `vscode.lua` reads VS Code's files, `tasks.lua` runs VS Code tasks |
| `nvim/cheatsheet.md` | Cheat sheet, shown when nvim starts without a file |
| `claude/abl-tmux.md` | Extra instructions for claude in the session |
| `install.sh`, `deploy.sh` | Per-user setup; copy to `/opt/abl-tmux` |
| `fetch-tools.sh`, `tools/bin/` | Download recent tmux and nvim; the downloads (not in git) |
| `openedge-project.json`, `src/`, `dump/`, `.vscode/` | Local test project (`.vscode/tasks.json` has sample tasks); only `.vscode/` is in git |
