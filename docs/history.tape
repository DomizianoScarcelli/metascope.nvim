# Clip 3 - History: ^H inside any picker, the dashboard, Tab to filter.
Output docs/history.gif
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
Type ":Caption 3 - History|Inside any picker, ^H opens that picker's history"
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
Sleep 1500ms
Ctrl+H
Sleep 2600ms
Tab
Sleep 2400ms
Tab
Sleep 2000ms
Type "hyb"
Sleep 1600ms
Enter
Sleep 1200ms

Hide
Escape
Type ":Caption The dashboard: one row per place, ranked by how often and how recently|Tab cycles the type - Enter jumps back - Ctrl-R re-runs the search"
Enter
Show
Sleep 3200ms
