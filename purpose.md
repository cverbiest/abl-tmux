# nvim + Claude + bash + tmux setup

The purpose of this workspace is to set up an alternative to VS Code (with the vscode-abl extension) for editing OpenEdge ABL.

# Steps

## Initial setup

- Define the tmux setup, starting from `claude-tmux.sh`.
- Use a dedicated nvim config for this setup. Copy only the useful parts of the current config; avoid bloat.
- Use keybindings that feel familiar to VS Code users, without alienating vi users.

## ABL editing

- The main focus is OpenEdge ABL; add the configuration for it.
- Other languages to support: bash, Python, PowerShell (pwsh).
- Examine the vscode-abl extension to see which of its functionality can be reused in this setup. Try to use its language server.
