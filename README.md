# metascope.nvim 🔭

An [Atuin](https://github.com/atuinsh/atuin)-style, visual, searchable, cross-session prompt history for Telescope.

Standard Telescope history plugins function like bash history: you hit up/down arrows blindly. **Metascope** creates a unified dashboard of your past searches (files, grep, buffers) complete with deduplication, timestamps, and an executing live-preview of the results *before* you even hit enter.

## ✨ Features
- **Visual History Dashboard**: Search through your previous Telescope queries.
- **Per-picker history**: `J` (or your key) in find-files shows file history only; in live-grep, grep only; in buffers, buffer history only.
- **Zero-Dependency Persistence**: Saves history across sessions using Neovim's native JSON encoding. No SQLite required.
- **Live Terminal Preview**: Automatically runs `rg` or `fd` in the background as you hover over past searches, previewing the results instantly.
- **Smart Deduplication**: Moves repeated searches to the top with a fresh timestamp.

## 📦 Installation

Defaults are applied on load (`max_history = 10000`, `J` in normal mode to open per-picker history). No `setup()` call required.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "DomizianoScarcelli/metascope.nvim", dependencies = { "nvim-telescope/telescope.nvim" } }
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use { "DomizianoScarcelli/metascope.nvim", requires = { "nvim-telescope/telescope.nvim" } }
```

Optional overrides:

```lua
require("metascope").setup({
    max_history = 5000,
    picker_history_keymap = "<C-h>", -- false to disable
    picker_history_keymap_mode = { "n", "i" },
})
```

## 🚀 Usage & Keymaps

Use the metascope wrappers so each picker gets the right history type (`files`, `grep`, `buffers`). Press your configured key (e.g. `J` in normal mode) inside a picker to open history **for that picker only**.

```lua
local metascope = require("metascope")

-- 1. The Atuin-Style History Dashboard (all types)
vim.keymap.set('n', '<leader>fh', function() metascope.history_picker() end, { desc = "All Telescope History" })

-- 2. Wrapped pickers (history type matches the picker)
vim.keymap.set('n', '<leader>ff', function() metascope.find_files({ hidden = true }) end, { desc = "Find files" })
vim.keymap.set('n', '<leader>fg', function() metascope.live_grep() end, { desc = "Live grep" })
vim.keymap.set('n', '<leader>fb', function() metascope.buffers() end, { desc = "Buffers" })

-- Optional: manual builtin wrap (keep default Telescope prompt titles for auto-detect)
-- local builtin = require('telescope.builtin')
-- vim.keymap.set('n', '<leader>ff', function()
--     builtin.find_files(metascope.enrich_opts("files", { hidden = true }))
-- end)
```

Custom pickers: pass `metascope_type` in opts or use `metascope.enrich_opts("files", opts)`.

`:Metascope` opens all history; `:Metascope files` filters by type. Telescope extension: `:Telescope metascope history`.
