#!/usr/bin/env bash
# deploy.sh — install or update abl-tmux for all users: copies the files users need
# from this repo to TARGET (default /opt/abl-tmux) and records the version in
# TARGET/VERSION. Each user then runs TARGET/install.sh once, and again after an
# update that changes the plugins (deploy.sh says so).
#
# Also copies tools/ (tmux and nvim from fetch-tools.sh) when present.
#
# Usage: deploy.sh [TARGET]
# Use sudo when TARGET isn't writable for you.
set -euo pipefail

HERE=$(dirname "$(readlink -f "$0")")
TARGET=$(readlink -m "${1:-/opt/abl-tmux}")
FILES=(install.sh README.md USER-GUIDE.md RELEASE-NOTES.md nvim tmux claude)
# tmux and nvim downloaded by fetch-tools.sh; without them users get the native packages
if [ -x "$HERE/tools/bin/tmux" ] && [ -x "$HERE/tools/bin/nvim" ]; then
    FILES+=(tools)
else
    echo "Note: no tools/bin (run ./fetch-tools.sh); users will use the native tmux and nvim." >&2
fi

# Only write into a new or empty directory, or an earlier copy
if [ -d "$TARGET" ] && [ -n "$(ls -A "$TARGET")" ] &&
    [ ! -f "$TARGET/VERSION" ] && [ ! -f "$TARGET/tmux/abl-tmux.sh" ]; then
    echo "$TARGET is not empty and isn't an abl-tmux copy; not touching it." >&2
    exit 1
fi
mkdir -p "$TARGET" 2>/dev/null && [ -w "$TARGET" ] ||
    { echo "Can't write to $TARGET; run with sudo." >&2; exit 1; }

# safe.directory: under sudo, git refuses a repo owned by someone else
version=$(git -c safe.directory="$HERE" -C "$HERE" describe --tags --always --dirty 2>/dev/null || echo unknown)
case "$version" in *-dirty) echo "WARNING: deploying uncommitted changes ($version)." >&2 ;; esac
old=$(cat "$TARGET/VERSION" 2>/dev/null || echo none)

plugins_changed=yes
cmp -s "$HERE/nvim/lazy-lock.json" "$TARGET/nvim/lazy-lock.json" && plugins_changed=no

for f in "${FILES[@]}"; do
    # --delete within the copied directories drops files removed from the repo
    rsync -a --delete --chmod=a+rX,go-w "$HERE/$f" "$TARGET/"
done
echo "$version" > "$TARGET/VERSION"
chmod a+r "$TARGET/VERSION"

echo "Deployed $version to $TARGET (was: $old)."
if [ "$plugins_changed" = yes ]; then
    echo "Plugins changed: every user runs $TARGET/install.sh again."
fi
echo "Users get an update notice on their next abl-tmux (what's new, rerun install.sh, restart"
echo "running sessions: abl-tmux -c in each workspace, then abl-tmux -K)."
