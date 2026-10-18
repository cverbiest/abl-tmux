#!/usr/bin/env bash
# fetch-tools.sh — download the latest stable tmux and Neovim into tools/bin, next to this
# script; abl-tmux and install.sh use them instead of the native packages (unless
# ABL_TMUX_NATIVE=1), and deploy.sh copies them along. Run again to update.
#   tmux:   static build from https://github.com/tmux/tmux-builds (latest release)
#   Neovim: AppImage from https://github.com/neovim/neovim (latest stable release)
# Linux x86_64/arm64 only.
set -euo pipefail

HERE=$(dirname "$(readlink -f "$0")")
BIN=$HERE/tools/bin
case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64) arch=arm64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$BIN"

tag=$(curl -fsSL https://api.github.com/repos/tmux/tmux-builds/releases/latest |
    sed -n 's/^  "tag_name": "\(.*\)",$/\1/p')
[ -n "$tag" ] || { echo "Can't find the latest tmux release." >&2; exit 1; }
echo "tmux $tag..."
curl -fsSL -o "$tmp/tmux.tar.gz" \
    "https://github.com/tmux/tmux-builds/releases/download/$tag/tmux-${tag#v}-linux-$arch.tar.gz"
tar xzf "$tmp/tmux.tar.gz" -C "$tmp" tmux
"$tmp/tmux" -V >/dev/null # runs here?
install -m 755 "$tmp/tmux" "$BIN/tmux"

echo "Neovim (latest stable)..."
curl -fsSL -o "$tmp/nvim" \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.appimage"
chmod 755 "$tmp/nvim"
"$tmp/nvim" --version >/dev/null # runs here (needs FUSE and a recent enough glibc)?
install -m 755 "$tmp/nvim" "$BIN/nvim"

echo
echo "$("$BIN/tmux" -V), $("$BIN/nvim" --version | head -1) in $BIN"
