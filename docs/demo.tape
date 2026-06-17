# Record the metascope demo GIF.
#   1. Install vhs:  brew install vhs   (or: go install github.com/charmbracelet/vhs@latest)
#   2. From the repo root:  vhs docs/demo.tape
# Produces docs/demo.gif.

Output docs/demo.gif

Set Shell "bash"
Set FontSize 18
Set Width 1280
Set Height 720
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 80ms

# Launch (hidden) so the recording starts on the editor.
Hide
Type "nvim -u docs/demo_init.lua lua/metascope/hybrid.lua"
Enter
Sleep 2s
Show
Sleep 1s

# ── Files: opens to your recent files, reveals the project as you type ──
Type ":Files"
Enter
Sleep 2s
Type "prev"
Sleep 2s
Ctrl+C
Sleep 1500ms

# ── Grep: recent searches first, live grep as you type ──
Type ":Grep"
Enter
Sleep 2s
Type "function"
Sleep 2500ms
Ctrl+C
Sleep 1500ms

# ── History dashboard: everything you've searched, then jump back ──
Type ":History"
Enter
Sleep 2s
Type "hist"
Sleep 2s
Enter
Sleep 2s
