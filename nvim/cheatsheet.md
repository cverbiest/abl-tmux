# abl-tmux cheat sheet                    Space ? reopens it · q closes it

## Panes
  Alt+1 / Alt+2 / Alt+3     editor / claude / terminal  (AZERTY: Alt+& é ")
  Ctrl+J                    switch between editor and terminal
  Alt+Z                     maximize / restore the current pane
  Mouse                     click to focus, drag borders, wheel scrolls
  Ctrl+Click file name      open it in nvim, from any pane (file:line too) · gf in nvim

## Typing (nvim starts in Normal mode, where letters are commands)
  i                         start typing (Insert mode) · Esc stops
  Ctrl+S                    save; ABL files compile and show their errors
  Ctrl+Z  or  u             undo · Ctrl+R redo
  v / V                     select characters / lines
  Ctrl+C (selection)        copy to the clipboard; paste with the terminal's key
  Ctrl+/                    toggle comment
  Alt+Up/Down               move line · Shift+Alt+Up/Down duplicate it

## Files
  Ctrl+P                    quick open file
  Ctrl+Shift+F  or  Space f g   search in files
  Ctrl+B                    explorer · Ctrl+Alt+X reveal the current file
  Ctrl+PageUp/PageDown      previous / next tab · Alt+W closes the tab

## Code
  F12  or  Ctrl+Click       go to definition · Alt+Left goes back
  Shift+F12                 find references
  K                         hover info
  F2                        rename symbol
  Ctrl+Space, Tab/Enter     completion: open, accept
  Shift+Alt+F               format document
  Ctrl+Alt+T                run a VS Code task (tasks.json) in a task pane

## Problems
  F8 / Shift+F8             next / previous problem
  Space d                   full message of the problem under the cursor
  Ctrl+Shift+M  or  Space x x   problems panel (Enter jumps, q closes)

## Quitting
  :w  :q  :qa               save / close window / quit nvim
  :qa!                      quit, discarding unsaved changes
  abl-tmux -c               (terminal) close the workspace cleanly
  Alt+B d                   detach; abl-tmux reattaches later

## More
  :Guide                    the full user guide (getting started, all features)
  F1  or  Ctrl+Shift+P      command palette
  Space (wait)              all Space keys · Space f k lists every key
  /ide  (in claude)         reconnect claude to nvim
  Space c b / Space c s     send the file / the selection to claude
