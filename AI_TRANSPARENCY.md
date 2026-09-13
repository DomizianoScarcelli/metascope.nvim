# AI transparency

**This plugin is 100% AI-written.** Every line of Lua, the tests, the demo tapes and this README were produced by an AI coding assistant (Claude, via Claude Code) working from prompts by the maintainer. The maintainer directs the work, tries the result in daily use, and decides what gets merged — but does not hand-write or line-by-line review the code.

## Why say this

metascope exists to solve one person's problem: Telescope forgets what you searched for. It is built and maintained the way you'd build a personal tool — fast, driven by what's annoying today, verified by using it — not the way you'd build a library other people depend on.

Being upfront about that lets you calibrate:

- **Expect bugs and unexpected behaviour.** Things are tested headlessly and in the maintainer's own setup (macOS, Neovim 0.12, lazy.nvim, Telescope 0.2). Other setups get whatever falls out of that.
- **Expect "slop".** Comments that over-explain, abstractions that exist because one prompt asked for them, defaults tuned to one person's habits. Read the code with that in mind.
- **Expect churn.** Behaviour changes when the maintainer's workflow changes. Pin a commit if you rely on it.
- **Expect no API stability promises.** Public function names have stayed put so far; that's a courtesy, not a contract.

## What that does *not* mean

- It doesn't mean nobody looks. Every change is exercised — pickers opened, keys pressed, files jumped to — before it lands, and the demo clips are recorded from the real thing.
- It doesn't mean issues are unwelcome. If it breaks for you, open one with what you ran and what happened; it will most likely be fixed by the same process that built it, and that process works better with a clear repro.
- It doesn't mean you can't read or fork it. The code is small (~1.5k lines) and plain Lua; if you'd rather own your own copy, please do.

## Practical advice

If you're evaluating whether to use it: try it for a week with your real history. If it makes finding things faster, keep it. If it does something surprising, `:Metascope` shows exactly what it recorded, `<C-d>` forgets an entry, and `rm ~/.local/share/nvim/telescope_metascope_history.json` resets everything — it never touches anything but that one file.
