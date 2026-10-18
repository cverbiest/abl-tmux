#!/usr/bin/env bash
# fetch-tools.sh — download the latest stable tmux and Neovim into tools/bin, next to this
# script; abl-tmux and install.sh use them instead of the native packages (unless
# ABL_TMUX_NATIVE=1), and deploy.sh copies them along. Run again to update.
#   tmux:   static build from https://github.com/tmux/tmux-builds (latest release)
#   Neovim: tarball from https://github.com/neovim/neovim (latest stable release), unpacked into
#           tools/nvim with tools/bin/nvim linking to it (no FUSE needed, unlike the AppImage)
#   ABL language server: the vscode-abl extension (riversidesoftware.openedge-abl-lsp) from the
#           VS Code Marketplace, Linux build with its own Java, unpacked into tools/ under the
#           name VS Code uses; for users without VS Code (abl.lua takes the newest of VS Code's
#           and this one). Newest stable version; --pre-release: newest pre-release.
# Linux x86_64/arm64 only.
#
# Usage: fetch-tools.sh [--pre-release]
set -euo pipefail

prerelease=false
case "${1:-}" in
    --pre-release) prerelease=true ;;
    "") ;;
    *) echo "Usage: $0 [--pre-release]" >&2; exit 2 ;;
esac

HERE=$(dirname "$(readlink -f "$0")")
BIN=$HERE/tools/bin
case "$(uname -m)" in
    x86_64) arch=x86_64 vscode_platform=linux-x64 ;;
    aarch64) arch=arm64 vscode_platform=linux-arm64 ;;
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
curl -fsSL -o "$tmp/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz"
mkdir "$tmp/nvim"
tar xzf "$tmp/nvim.tar.gz" -C "$tmp/nvim" --strip-components=1
"$tmp/nvim/bin/nvim" --version >/dev/null # runs here (glibc 2.31 or newer)?
rm -rf "$HERE/tools/nvim" "$BIN/nvim"
mv "$tmp/nvim" "$HERE/tools/nvim"
ln -s ../nvim/bin/nvim "$BIN/nvim"

echo "ABL language server (vscode-abl, $($prerelease && echo pre-release || echo stable))..."
# Newest version for this platform: "version assetUri"
read -r lsp_version lsp_uri < <(curl -fsS -X POST https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery \
    -H 'Content-Type: application/json' -H 'Accept: application/json;api-version=3.0-preview.1' \
    -d '{"filters":[{"criteria":[{"filterType":7,"value":"riversidesoftware.openedge-abl-lsp"}]}],"flags":19}' |
    python3 -I -c '
import json, sys
platform, prerelease = sys.argv[1], sys.argv[2] == "true"
ext = json.load(sys.stdin)["results"][0]["extensions"][0]
for v in ext["versions"]:  # newest first
    pre = any(p["key"] == "Microsoft.VisualStudio.Code.PreRelease" and p["value"] == "true"
              for p in v.get("properties", []))
    if v.get("targetPlatform") == platform and (prerelease or not pre):
        print(v["version"], v["assetUri"])
        break
' "$vscode_platform" "$prerelease")
[ -n "${lsp_uri:-}" ] || { echo "Can't find the vscode-abl extension on the Marketplace." >&2; exit 1; }
lsp_dir=$HERE/tools/riversidesoftware.openedge-abl-lsp-$lsp_version-$vscode_platform
if [ -d "$lsp_dir" ]; then
    echo "  $lsp_version: already there"
else
    curl -fsSL --compressed -o "$tmp/abl.vsix" "$lsp_uri/Microsoft.VisualStudio.Services.VSIXPackage"
    unzip -q "$tmp/abl.vsix" 'extension/*' -d "$tmp/vsix"
    "$tmp/vsix/extension/jre/bin/java" -version 2>/dev/null # its Java runs here?
    rm -rf "$HERE"/tools/riversidesoftware.openedge-abl-lsp-*
    mv "$tmp/vsix/extension" "$lsp_dir"
fi

echo
echo "$("$BIN/tmux" -V), $("$BIN/nvim" --version | head -1) in $BIN"
echo "ABL language server $lsp_version in $lsp_dir"
