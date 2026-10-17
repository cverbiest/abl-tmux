#!/usr/bin/env bash
# abl-open.sh — open the word that was Ctrl+clicked in a tmux pane in the session's nvim,
# when it names an existing file (VS Code's Ctrl+click on a path in the terminal).
# Anything else (URLs, plain words) is ignored, so the click only does what it did before.
# Called by tmux.conf with: WORD PANE_DIR NVIM_SOCKET EDITOR_PANE TMUX_SOCKET
# WORD may be "file", "file:line" or "file:line:col", with quotes or punctuation around it.
set -uo pipefail

word=$1 dir=$2 sock=$3 editor=$4 tmux_sock=$5
tm() { tmux -S "$tmux_sock" "$@"; }

# Strip what often surrounds a path in output: quotes, brackets, trailing punctuation
word=${word#[\"\'\(\[\<\`]}
word=${word%[\"\'\)\]\>\`,;.]}
word=${word%[\"\'\)\]\>\`]}
line=
if [[ $word =~ ^(.+):([0-9]+)(:[0-9]+)?:?$ ]]; then
    word=${BASH_REMATCH[1]}
    line=${BASH_REMATCH[2]}
fi

case $word in
    "~/"*) file=$HOME/${word#\~/} ;;
    /*) file=$word ;;
    *) file=$dir/$word ;;
esac
[ -f "$file" ] || exit 0

if [ -z "$sock" ] || [ ! -S "$sock" ]; then
    tm display-message "abl-open: nvim isn't listening (restart the session to enable Ctrl+click)"
    exit 0
fi
# In a single-quoted Vim string only ' needs escaping (doubled)
f=${file//\'/\'\'}
expr="execute('drop ' .. fnameescape('$f'))"
[ -n "$line" ] && expr="$expr .. execute('$line')"
if ! nvim --server "$sock" --remote-expr "$expr" >/dev/null 2>&1; then
    tm display-message "abl-open: couldn't open $file in nvim"
    exit 0
fi
tm select-pane -t "$editor"
