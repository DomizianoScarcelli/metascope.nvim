# Clip 2 - Grep: recent searches first, matching ones pinned while you type.
Output docs/grep.gif
Set Shell "bash"
Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 16
Set Width 1400
Set Height 720
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 90ms
Set Framerate 30

Hide
Type "nvim --clean -u docs/demo_init.lua README.md"
Enter
Sleep 4s
Escape
Type ":Caption 2 - Grep|Recent searches first - the ones matching what you type stay pinned"
Enter
Show
Sleep 2800ms

Hide
Escape
Type ":Uncaption"
Enter
Escape
Type ":Grep"
Enter
Sleep 600ms
Show
Sleep 2400ms
Type "fre"
Sleep 2800ms
Enter
Sleep 1200ms

Hide
Escape
Type ":Caption Straight back to where that search took you|(no results list to dig through again)"
Enter
Show
Sleep 2800ms
