#!/usr/bin/env bash
# abl-tmux.sh — VS Code-like editing workspace in tmux: nvim, claude and a shell.
# Derived from ~/bin/claude-tmux.sh (its nvim layout).
#
#   +-------------------------+-----------+
#   | nvim                    | claude    |
#   |                         |           |
#   +-------------------------+           |
#   | bash                    |           |
#   +-------------------------+-----------+
#
# claude gets 30% of the width (at least 80 cols from 160 cols up), bash 20%
# of the height. Runs on its own tmux server (-L abl) with the tmux.conf next
# to this script, and starts nvim with NVIM_APPNAME=nvim-abl.
# One session per workspace, named abl-<dirname>. The workspace root is the
# nearest directory up from DIR with an openedge-project.json (else DIR itself);
# every pane gets it as $VSCODE_WS. Asks before opening a root without
# openedge-project.json. Before a new session, runs the open hooks: the executables in
# /etc/abl-tmux/open.d and ~/.config/abl-tmux/open.d, with the workspace root as argument
# (site checks, e.g. a workspace setup that isn't done yet); one that fails stops the start.
#
# Usage: abl-tmux.sh [OPTION] [DIR | FILE.code-workspace]
#   (no option)     : attach to the session for DIR (default: $PWD), creating it if needed
#   -l, --list      : list running sessions
#   --connect       : pick a running session or a workspace under ~/workspaces
#                     ($ABL_WORKSPACES) with fzf, then open it
#   -c, --close     : quit nvim, close the session for DIR and stop leftover
#                     language servers (refuses while nvim has unsaved changes)
#   -k, --kill      : close the session for DIR without quitting nvim first
#   -K, --kill-all  : close all sessions (stops the abl tmux server)
#   -r, --reload    : restart claude in the session for DIR
#   -V, --version   : show the installed version and the tmux/nvim it uses
#
# Uses the tmux and nvim in tools/bin (fetch-tools.sh) when present; ABL_TMUX_NATIVE=1 uses
# the native packages instead.
#   -h, --help      : show this help
set -euo pipefail

usage() { awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONF="$SCRIPT_DIR/tmux.conf"
SOCKET=${ABL_TMUX_SOCKET:-abl}  # override to test without touching running sessions
NVIM_APP=nvim-abl
# tmux and nvim: the bundled ones (fetch-tools.sh, tools/bin) unless ABL_TMUX_NATIVE=1 or
# they're missing. The tmux server inherits these, so everything in the session uses the same
# ones: an older tmux client can't talk to a newer server.
TOOLS=$(readlink -f "$SCRIPT_DIR/../tools/bin" 2>/dev/null || true)
if [ -z "${ABL_TMUX_NATIVE:-}" ] && [ -x "$TOOLS/tmux" ] && [ -x "$TOOLS/nvim" ]; then
    export PATH="$TOOLS:$PATH"
fi
ABL_TMUX_BIN=$(command -v tmux) || { echo "tmux not found" >&2; exit 1; }
ABL_NVIM_BIN=$(command -v nvim) || { echo "nvim not found" >&2; exit 1; }
export ABL_TMUX_BIN ABL_NVIM_BIN
tm() { "$ABL_TMUX_BIN" -L "$SOCKET" -f "$CONF" "$@"; }
# claude connects to nvim by itself (--ide) and learns about this setup from claude/abl-tmux.md
CLAUDE_CMD=(claude --ide)
CLAUDE_MD=$(readlink -f "$SCRIPT_DIR/../claude/abl-tmux.md" || true)
[ -f "$CLAUDE_MD" ] && CLAUDE_CMD+=(--append-system-prompt-file "$CLAUDE_MD")

# The vscode-abl extension nvim uses (as in abl.lua): the newest of VS Code's and tools/,
# VS Code's with equal versions; not ~/.vscode-server-bad or folders VS Code marked obsolete
abl_lsp_dir() {
    local d v
    for d in "$HOME"/.vscode*/extensions/riversidesoftware.openedge-abl-lsp-* \
        "$SCRIPT_DIR"/../tools/riversidesoftware.openedge-abl-lsp-*; do
        [ -d "$d" ] || continue
        case $d in */.vscode*-bad/*) continue ;; esac
        grep -qF "\"$(basename "$d")\":true" "$(dirname "$d")/.obsolete" 2>/dev/null && continue
        v=${d##*openedge-abl-lsp-}
        case $d in */.vscode*) echo "${v%%-*} 2 $(readlink -f "$d")" ;; *) echo "${v%%-*} 1 $(readlink -f "$d")" ;; esac
    done | sort -k1,1V -k2,2n | tail -1 | cut -d' ' -f3-
}

# Open hooks: system-wide first, then the user's
HOOK_DIRS=(/etc/abl-tmux/open.d "${XDG_CONFIG_HOME:-$HOME/.config}/abl-tmux/open.d")
open_hooks() {
    local d f
    for d in "${HOOK_DIRS[@]}"; do
        for f in "$d"/*; do
            case $f in *~|*.bak|*.disabled) continue ;; esac
            if [ -f "$f" ] && [ -x "$f" ]; then echo "$f"; fi
        done
    done
}

ACTION=open
case "${1:-}" in
    -l|--list)     ACTION=list;   shift ;;
    --connect)     ACTION=connect; shift ;;
    -c|--close)    ACTION=close;  shift ;;
    -k|--kill)     ACTION=kill;   shift ;;
    -K|--kill-all) ACTION=killall; shift ;;
    -r|--reload)   ACTION=reload; shift ;;
    -V|--version)
        cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "development copy (no VERSION)"
        echo "$("$ABL_TMUX_BIN" -V) ($ABL_TMUX_BIN), $("$ABL_NVIM_BIN" --version | head -1) ($ABL_NVIM_BIN)"
        echo "ABL language server: $(abl_lsp_dir || true)"
        hooks=$(open_hooks | paste -sd ' ')
        echo "Open hooks: ${hooks:-none}"
        exit 0 ;;
    -h|--help)     usage; exit 0 ;;
    -*)            echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
esac
# Sets DIR (the workspace root) and NAME (its session) from a directory or .code-workspace file
set_dir() {
    local d
    DIR=$(readlink -f "$1")
    case "$DIR" in *.code-workspace) [ -f "$DIR" ] && DIR=$(dirname "$DIR") ;; esac
    [ -d "$DIR" ] || { echo "Not a directory: $DIR" >&2; exit 1; }
    # Started in a subdirectory (e.g. one of the git projects): use the workspace root
    d=$DIR
    while [ "$d" != / ] && [ ! -f "$d/openedge-project.json" ]; do d=$(dirname "$d"); done
    [ -f "$d/openedge-project.json" ] && DIR=$d
    # tmux forbids '.' and ':' in session names
    NAME="abl-$(basename "$DIR" | tr -c 'A-Za-z0-9_\n-' '_')"
}

# Running sessions, then the workspaces (directories with an openedge-project.json) under
# $ABL_WORKSPACES or ~/workspaces that have none; prints the directory picked with fzf.
# Lines are "state name path"; the path is read back from the picked line.
pick_workspace() {
    command -v fzf >/dev/null || { echo "fzf is not installed." >&2; exit 1; }
    local root=${ABL_WORKSPACES:-$HOME/workspaces} running dir name state line
    running=$(tm list-sessions -F '#{session_path}' 2>/dev/null || true)
    line=$({
        tm list-sessions -F '#{?session_attached,attached,running}	#{session_name}	#{session_path}' 2>/dev/null |
            while IFS=$'\t' read -r state name dir; do
                printf '%-8s  %-24s  %s\n' "$state" "$name" "${dir/#$HOME/\~}"
            done
        for dir in "$root"/*/openedge-project.json; do
            [ -f "$dir" ] || continue
            dir=$(readlink -f "$(dirname "$dir")")
            grep -qxF "$dir" <<<"$running" && continue
            printf '%-8s  %-24s  %s\n' new "abl-$(basename "$dir")" "${dir/#$HOME/\~}"
        done
    } | fzf --no-sort --prompt 'workspace> ' || true)
    [ -n "$line" ] || return 0
    dir=$(sed -E 's/^[^ ]+ +[^ ]+ +//' <<<"$line")
    echo "${dir/#\~/$HOME}"
}

if [ "$ACTION" = connect ]; then
    choice=$(pick_workspace)
    [ -n "$choice" ] || exit 0  # cancelled
    set_dir "$choice"
    ACTION=open
else
    set_dir "${1:-$PWD}"
fi

has_session() { tm has-session -t "=$NAME" 2>/dev/null; }

check_config() {
    if [ ! -e "$HOME/.config/$NVIM_APP" ]; then
        echo "~/.config/$NVIM_APP is missing; run $SCRIPT_DIR/../install.sh first." >&2
        exit 1
    fi
}

# After a deploy (VERSION differs from what install.sh recorded): show what's new and offer
# to rerun install.sh; and say when running sessions still use an older version.
# A development copy has no VERSION and is never checked.
check_version() {
    local current installed server notes answer=
    current=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null) || return 0
    installed=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/abl-tmux/installed-version" 2>/dev/null || true)
    if [ "$current" != "$installed" ]; then
        notes="$SCRIPT_DIR/../RELEASE-NOTES.md"
        echo "abl-tmux was updated to $current (installed: ${installed:-unknown}). What's new:" >&2
        # Release-note sections newer than the installed version (only the newest when unknown)
        awk -v old="$(plain_version "$installed")" '
            /^## / { if (seen && (old == "" || $2 == old)) exit; seen = 1 }
            seen' "$notes" 2>/dev/null | sed 's/^/  /' >&2
        if [ -t 0 ]; then
            answer=$(choose "Run install.sh now (plugins and links)?" "y	yes, run install.sh" "n	no, later")
            case "$answer" in
                y) "$SCRIPT_DIR/../install.sh" || echo "install.sh failed; continuing." >&2 ;;
                *) echo "Skipped; run $(readlink -f "$SCRIPT_DIR/..")/install.sh later." >&2 ;;
            esac
        fi
    fi
    # Servers started before versions were recorded have none: older too
    tm list-sessions >/dev/null 2>&1 || return 0
    server=$(tm show-options -gqv @abl_version 2>/dev/null || true)
    if [ "$server" != "$current" ]; then
        echo "Running sessions were started with ${server:-an older} abl-tmux. To use $current, close them" \
            "(abl-tmux -c in each workspace), then abl-tmux -K." >&2
    fi
}

# v0.3.0-beta.1-2-gabc123 (git describe) -> 0.3.0-beta.1, as in RELEASE-NOTES.md
plain_version() {
    local v=${1#v}
    echo "${v%%-[0-9]*-g*}"
}

# Asks QUESTION and prints the key of the option picked: with fzf when installed, else by
# typing the key. Options are "key<TAB>label"; prints nothing when cancelled (Esc, Enter).
choose() {
    local question=$1 opt answer
    shift
    if command -v fzf >/dev/null; then
        printf '%s\n' "$@" | fzf --delimiter '\t' --with-nth 2 --no-sort --reverse --height ~10 \
            --header "$question" --prompt '> ' | cut -f1 || true
        return
    fi
    echo "$question" >&2
    for opt in "$@"; do echo "  ${opt%%	*}) ${opt#*	}" >&2; done
    read -r -p "Choice: " answer || true
    for opt in "$@"; do [ -n "$answer" ] && [ "$answer" = "${opt%%	*}" ] && echo "$answer"; done
}

# Runs the open hooks with the workspace root; stops when one fails
run_open_hooks() {
    local hook rc hooks
    mapfile -t hooks < <(open_hooks)
    # On the terminal: hooks may ask questions
    for hook in "${hooks[@]}"; do
        "$hook" "$DIR" || { rc=$?; echo "Not started: ${hook/#$HOME/\~} stopped it (exit $rc)." >&2; exit 1; }
    done
}

# A workspace root has an openedge-project.json; ask before opening a directory without one
check_workspace() {
    run_open_hooks
    [ -f "$DIR/openedge-project.json" ] && return 0
    echo "WARNING: $DIR has no openedge-project.json; it may not be a workspace root." >&2
    case "$(choose "Open it anyway?" "n	no, stop" "y	yes, open it")" in
        y) ;;
        *) echo "Not started." >&2; exit 1 ;;
    esac
}

create_session() {
    local width height claude_size editor shell claude
    width=$(tput cols 2>/dev/null || echo 160)
    height=$(tput lines 2>/dev/null || echo 50)
    claude_size=$((width * 30 / 100))
    # Give claude a usable 80 cols when nvim still keeps 80+
    if [ "$width" -ge 160 ] && [ "$claude_size" -lt 80 ]; then claude_size=80; fi
    if [ "$width" -lt 120 ]; then
        echo "WARNING: terminal is only ${width} cols wide (recommended: 160+)." >&2
    fi

    # nvim listens here too (init.lua), for Ctrl+click on file names in the other panes
    local nvim_sock=${XDG_RUNTIME_DIR:-/tmp}/abl-tmux-$(id -u).$SOCKET.$NAME.nvim
    editor=$(tm new-session -d -s "$NAME" -x "$width" -y "$height" -c "$DIR" -e "ABL_NVIM_SOCKET=$nvim_sock" \
        -e "NVIM_APPNAME=$NVIM_APP" -e "VSCODE_WS=$DIR" -P -F '#{pane_id}')
    tm set-option -g @abl_conf "$CONF"
    tm set-option -g @abl_open "$SCRIPT_DIR/abl-open.sh"
    tm set-option -g @abl_user "$(id -un)"
    tm set-option -g @abl_tmux "$ABL_TMUX_BIN"
    # The version this tmux server runs, for check_version (only the first session sets it)
    [ -n "$(tm show-options -gqv @abl_version)" ] ||
        tm set-option -g @abl_version "$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo dev)"
    # A detached session ignores -x/-y unless the window size is pinned manually
    tm set-option   -t "=$NAME:" window-size manual
    tm resize-window -t "=$NAME:" -x "$width" -y "$height"
    shell=$(tm split-window -v -d -t "$editor" -l 20% -c "$DIR" -P -F '#{pane_id}')
    claude=$(tm split-window -h -d -t "$editor" -f -l "$claude_size" -c "$DIR" -P -F '#{pane_id}' "${CLAUDE_CMD[@]}")
    # Typed rather than run directly, so quitting nvim leaves a shell
    tm send-keys -t "$editor" "$(printf '%q' "$ABL_NVIM_BIN")" Enter
    tm select-pane -t "$editor"
    tm set-option -w -t "=$NAME:" @editor_pane "$editor"
    tm set-option -w -t "=$NAME:" @shell_pane "$shell"
    tm set-option -w -t "=$NAME:" @claude_pane "$claude"
    tm set-option -w -t "=$NAME:" @nvim_socket "$nvim_sock"
    # Hand sizing back to the attaching client (same terminal, so panes keep their widths)
    tm set-option -t "=$NAME:" window-size latest
    echo "Started session '$NAME' in $DIR."
}

attach_session() {
    case "${TMUX:-}" in
        "") tm attach-session -t "=$NAME" ;;
        */"$SOCKET",*) tm switch-client -t "=$NAME" ;;
        *)
            # Inside another tmux server: nest, its prefix (Ctrl+B) wins over ours
            echo "Nesting inside another tmux; use Alt+B as prefix here." >&2
            TMUX='' tm attach-session -t "=$NAME"
            ;;
    esac
}

reload_claude() {
    local claude
    claude=$(tm show-options -wqv -t "=$NAME:" @claude_pane)
    if [ -n "$claude" ] && tm list-panes -s -t "=$NAME" -F '#{pane_id}' | grep -qxF "$claude"; then
        tm respawn-pane -k -t "$claude" -c "$DIR" "${CLAUDE_CMD[@]}"
    else
        claude=$(tm split-window -h -d -f -t "=$NAME:" -l 30% -c "$DIR" -P -F '#{pane_id}' "${CLAUDE_CMD[@]}")
        tm set-option -w -t "=$NAME:" @claude_pane "$claude"
    fi
    echo "Restarted claude in '$NAME'."
}

# Quit nvim the normal way, so it stops its ABL language server.
# Fails when nvim stays open (unsaved changes).
quit_editor() {
    local editor
    editor=$(tm show-options -wqv -t "=$NAME:" @editor_pane)
    is_nvim() { [ "$(tm display-message -p -t "$editor" '#{pane_current_command}' 2>/dev/null)" = nvim ]; }
    [ -n "$editor" ] && is_nvim || return 0
    tm send-keys -t "$editor" 'C-\' C-n ':qa' Enter
    for _ in $(seq 50); do
        # Give its language server a moment to exit too
        is_nvim || { sleep 1; return 0; }
        sleep 0.2
    done
    return 1
}

# Language servers started by this nvim config whose nvim is gone (they hold the
# project, so new ones don't compile), with their AVMs
stop_leftover_servers() {
    local pid parent n=0
    for pid in $(pgrep -u "$(id -u)" -x java); do
        tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -q '/abl-lsda\.jar$' || continue
        tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -qx "NVIM_APPNAME=$NVIM_APP" || continue
        parent=$(ps -o ppid= -p "$pid") || continue  # exited meanwhile
        [ "$(ps -o comm= -p $parent)" = nvim ] && continue  # unquoted: ps pads the pid
        kill $(pgrep -P "$pid") "$pid" 2>/dev/null && n=$((n + 1))
    done
    [ "$n" -eq 0 ] || echo "Stopped $n leftover language server(s)."
}

case "$ACTION" in
    list)
        tm list-sessions -F '#{session_name}  #{session_path}#{?session_attached,  [attached],}' 2>/dev/null ||
            echo "No sessions running."
        ;;
    close)
        if has_session && ! quit_editor; then
            echo "nvim in '$NAME' didn't quit (unsaved changes?); session left open." >&2
            exit 1
        fi
        stop_leftover_servers
        # Last: when run from inside the session, this ends the script too
        if has_session; then
            echo "Closed '$NAME'."
            tm kill-session -t "=$NAME"
        fi
        ;;
    kill)
        has_session || { echo "No session '$NAME'." >&2; exit 1; }
        tm kill-session -t "=$NAME" && echo "Closed '$NAME'."
        ;;
    killall)
        tm kill-server 2>/dev/null && echo "Closed all sessions." || echo "No sessions running."
        ;;
    reload)
        has_session || { echo "No session '$NAME'." >&2; exit 1; }
        reload_claude
        ;;
    open)
        check_config
        check_version
        has_session || { check_workspace; create_session; }
        attach_session
        ;;
esac
