# Clip 1 - Files: recents first, project as you type, cursor restored.
#   vhs docs/files.tape   (from the repo root; needs `brew install vhs`)
Output docs/files.gif
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
Type ":Caption 1 - Files|Your recent files come first - the whole project as you type"
Enter
Show
Sleep 2800ms

Hide
Escape
Type ":Uncaption"
Enter
Escape
Type ":Files"
Enter
Sleep 600ms
Show
Sleep 2600ms
Type "prev"
Sleep 2400ms
Enter
Sleep 1200ms

Hide
Escape
Type ":Caption You land where you left off|(cursor back on the line you were on last time)"
Enter
Show
Sleep 2800ms
