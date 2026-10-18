#!/usr/bin/env bash
# install.sh — link this workspace's configs into place:
#   ~/.config/nvim-abl -> nvim/        (used via NVIM_APPNAME=nvim-abl)
#   ~/bin/abl-tmux     -> tmux/abl-tmux.sh
# Existing files that aren't these links are left alone.
set -euo pipefail

HERE=$(dirname "$(readlink -f "$0")")

link() {
    local target=$1 link=$2
    if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$target" ]; then
        echo "ok      $link"
    elif [ -e "$link" ] || [ -L "$link" ]; then
        echo "SKIP    $link exists and points elsewhere" >&2
    else
        mkdir -p "$(dirname "$link")"
        ln -s "$target" "$link"
        echo "linked  $link -> $target"
    fi
}

[ -x "$HERE/tmux/abl-tmux.sh" ] || chmod +x "$HERE/tmux/abl-tmux.sh"
link "$HERE/nvim" "$HOME/.config/nvim-abl"
link "$HERE/tmux/abl-tmux.sh" "$HOME/bin/abl-tmux"

echo
echo "Installing nvim plugins (versions from lazy-lock.json)..."
NVIM_APPNAME=nvim-abl nvim --headless "+Lazy! restore" +qa
case ":$PATH:" in *":$HOME/bin:"*) ;; *) echo "Note: ~/bin is not on your PATH." >&2 ;; esac
# abl-tmux compares this with the deployed VERSION and offers to rerun install.sh
if [ -f "$HERE/VERSION" ]; then
    state=${XDG_STATE_HOME:-$HOME/.local/state}/abl-tmux
    mkdir -p "$state" && cp "$HERE/VERSION" "$state/installed-version"
fi
echo "Done. Start with: abl-tmux [workspace dir]"
