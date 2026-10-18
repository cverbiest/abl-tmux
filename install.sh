#!/usr/bin/env bash
# install.sh — link this workspace's configs into place:
#   ~/.config/nvim-abl -> nvim/        (used via NVIM_APPNAME=nvim-abl)
#   ~/bin/abl-tmux     -> tmux/abl-tmux.sh
# Existing files that aren't these links are left alone.
#
# Usage: install.sh [--cce | --no-cce]
#   --no-cce : turn off the CCE features (APPL.env checks, CreateWorkspace offer)
#   --cce    : turn them on again (the default)
# The choice is kept in ~/.config/abl-tmux/config; without an option it stays as it was.
set -euo pipefail

HERE=$(dirname "$(readlink -f "$0")")
CONFIG_FILE=${XDG_CONFIG_HOME:-$HOME/.config}/abl-tmux/config

cce=
case "${1:-}" in
    --cce) cce=1 ;;
    --no-cce) cce=0 ;;
    "") ;;
    -h|--help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (use --cce or --no-cce)" >&2; exit 2 ;;
esac
if [ -n "$cce" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    { grep -v '^cce=' "$CONFIG_FILE" 2>/dev/null || true; echo "cce=$cce"; } > "$CONFIG_FILE.new"
    mv "$CONFIG_FILE.new" "$CONFIG_FILE"
fi

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
# The nvim abl-tmux uses: tools/bin (fetch-tools.sh) unless ABL_TMUX_NATIVE=1
NVIM=nvim
if [ -z "${ABL_TMUX_NATIVE:-}" ] && [ -x "$HERE/tools/bin/nvim" ]; then NVIM=$HERE/tools/bin/nvim; fi
NVIM_APPNAME=nvim-abl "$NVIM" --headless "+Lazy! restore" +qa
case ":$PATH:" in *":$HOME/bin:"*) ;; *) echo "Note: ~/bin is not on your PATH." >&2 ;; esac
# abl-tmux compares this with the deployed VERSION and offers to rerun install.sh
if [ -f "$HERE/VERSION" ]; then
    state=${XDG_STATE_HOME:-$HOME/.local/state}/abl-tmux
    mkdir -p "$state" && cp "$HERE/VERSION" "$state/installed-version"
fi
if [ "$(sed -n 's/^cce=//p' "$CONFIG_FILE" 2>/dev/null | tail -1)" = 0 ]; then
    echo "CCE features: off (install.sh --cce turns them on)"
else
    echo "CCE features: on (install.sh --no-cce turns them off)"
fi
echo "Done. Start with: abl-tmux [workspace dir]"
