# abl-tmux: ABL editing in nvim + claude + tmux

This is a spare time project, updates will be accordingly

A VS Code-like setup for OpenEdge ABL: nvim (Neovim editor), Claude Code and a bash terminal in one tmux
window. It opens existing VS Code ABL workspaces as they are and reuses the vscode-abl language server.

- **Using it:** [USER-GUIDE.md](USER-GUIDE.md): getting started and all features (in nvim: `:Guide`).
- **What changed:** [RELEASE-NOTES.md](RELEASE-NOTES.md).
- **Plan, achievements, to do, gaps with vscode-abl:** [PROJECT-PLAN.md](PROJECT-PLAN.md).
- **Development notes and test results:** [setup-notes.md](setup-notes.md).

## Features highlight

* Familiar for VsCode users without alienating vi users
* Re-use existing config where possible, openedge-project.json, .vscode/tasks.json, ...
* Paste images in claude pane
* ...


## Installing and updating (admin)

* `./fetch-tools.sh` downloads into `tools/` (not in git, about 250 MB):
  * latest stable tmux (static, github.com/tmux/tmux-builds) and Neovim (release tarball, no FUSE),
    used instead of the native packages unless `ABL_TMUX_NATIVE=1`
  * the vscode-abl extension (Marketplace pre-release, `--stable` for stable), for users without
    VS Code; nvim takes the newest of this and the user's VS Code copy
* `./deploy.sh [target]` copies what users need to `/opt/abl-tmux` (or `target`) and writes `VERSION`
  (`git describe`). Use sudo when the target isn't writable. It only writes into a new directory or an earlier copy, takes
  `tools/` along and says when the plugins changed.
* Each user runs `/opt/abl-tmux/install.sh` once. After a deploy, `abl-tmux` shows what's new and offers
  to rerun it.
* Site checks before a session opens (e.g. an unfinished workspace setup): open hooks in
  `/etc/abl-tmux/open.d/` (user guide, Advanced).
* Plugins install into `~/.local/share/nvim-abl`, at the versions in `nvim/lazy-lock.json`.

To update: run `fetch-tools.sh` and `deploy.sh` again.

## WezTerm terminal

abl-tmux works in any terminal of at least 160 columns, but some features require terminal configuration.

A matching WezTerm config is at [github.com/cverbiest/wezterm-config](https://github.com/cverbiest/wezterm-config).
It adds:
* Ctrl+Alt+V pastes a clipboard image into claude as a file path (uploaded to the server on SSH panes)
* the tab shows the workspace

See [WezTerm](USER-GUIDE.md#wezterm) in the user guide.

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

## License

MIT, see [LICENSE](LICENSE), for the files in this repository. The downloads in `tools/` keep their own:
* tmux: ISC
* Neovim: Apache 2.0 and Vim license
* vscode-abl extension: MIT; its ABL language server is Riverside Software's, under their terms
