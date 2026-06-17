# metascope.nvim 🔭

An [Atuin](https://github.com/atuinsh/atuin)-style, visual, searchable, cross-session prompt history for Telescope.

Standard Telescope history plugins function like bash history: you hit up/down arrows blindly. **Metascope** creates a unified dashboard of your past searches (files, grep, buffers) — and remembers *the file you actually opened*, so picking a history entry jumps you straight back there in one step instead of re-running a search and dumping you into a results list.

## ✨ Features
- **Hybrid files + history picker**: One picker that opens to your frecency-ranked recent files and reveals the full project tree the moment you start typing — frecent files stay biased to the top. The best `<leader>ff` replacement.
- **Jump to the destination, not the query**: Metascope records the file (and line) you opened, so selecting a history entry (`→` marked rows) takes you straight there. Press `<C-r>` to re-run the search instead.
- **Frecency ranking**: History is ordered by frequency × recency, so the row you want is usually already at the top — no searching required.
- **Project-aware**: Entries are tagged with the project (cwd) they came from and boosted when you're back in that project.
- **Visual History Dashboard**: Fuzzy-search your previous queries and destinations with a live preview.
- **Per-picker history**: `J` (or your key) in find-files shows file history only; in live-grep, grep only; in buffers, buffer history only.
- **Zero-Dependency Persistence**: Saves history across sessions using Neovim's native JSON encoding — debounced, written off the main loop, and merge-safe across concurrent nvim instances. No SQLite required.
- **Live Terminal Preview**: Previews the recorded file instantly; for query-only entries it runs `rg`/`fd` in the background.
- **Extensible**: Register custom/extension pickers (LSP symbols, git files, …) with `register_type` + `track`.

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
    picker_history_keymap = "<C-h>", -- open per-picker history; false to disable
    picker_history_keymap_mode = { "n", "i" },
    resume_keymap = "<C-r>",          -- in the dashboard: re-run the search instead of jumping; false to disable
    cwd_boost = 4,                    -- frecency multiplier for entries from the current project
    half_life_days = 3,               -- recency decay: an entry's weight halves every N days
    save_debounce_ms = 1000,          -- coalesce rapid writes into one async flush

    -- Hybrid files + history picker
    hybrid = {
        source_types = { "files", "buffers" }, -- history types that resolve to a file
        frecency_bonus = 8,                    -- how strongly frecency biases ranking while typing
        show_all_on_empty = false,             -- empty prompt: recents only (false) or whole tree (true)
        cwd_only = true,                       -- only surface recents from the current project
        find_command = nil,                    -- override the file-listing command, e.g. { "fd", "--type", "f" }
    },

    -- Set the three keymaps for you. Use `true` for the recommended bindings,
    -- a table to customise, or omit/false to bind them yourself (see below).
    keymaps = true, -- <leader>ff find_files · <leader>fh history · <leader>fo hybrid
})
```

### Dashboard keymaps

| Key | Action |
| --- | --- |
| `<CR>` | Jump to the recorded destination (or re-run the search if none) |
| `<C-r>` | Re-run the original search |
| `<C-d>` / `dd` | Delete the entry |

### Custom pickers

Register a type once, then wrap any picker with `track` so its history is recorded and resumable:

```lua
local metascope = require("metascope")
metascope.register_type("symbols", {
    label = "Sym", icon = " ",
    resume = function(opts) require("telescope.builtin").lsp_document_symbols(opts) end,
})
vim.keymap.set("n", "<leader>fs", function()
    require("telescope.builtin").lsp_document_symbols(metascope.track("symbols", {}))
end)
```

## 🚀 Three ways to search

Metascope gives you three distinct entry points; bind whichever you like (or all three).

| Function | What it does | Recommended key |
| --- | --- | --- |
| `metascope.find_files()` / `live_grep()` / `buffers()` | **Standard Telescope**, transparently recording history. Drop-in for the builtins. | `<leader>ff` / `fg` / `fb` |
| `metascope.history_picker()` | **The history dashboard** — fuzzy-search past queries & destinations across all types. | `<leader>fh` |
| `metascope.hybrid()` | **Hybrid** — recent files (frecency-ranked) up front, full file tree on first keystroke. | `<leader>fo` |

The quickest setup is `keymaps = true` in `setup()` (binds exactly the three above). To wire them yourself:

```lua
local metascope = require("metascope")

-- 1. Standard Telescope, with history recording
vim.keymap.set('n', '<leader>ff', function() metascope.find_files({ hidden = true }) end, { desc = "Find files" })
vim.keymap.set('n', '<leader>fg', function() metascope.live_grep() end, { desc = "Live grep" })
vim.keymap.set('n', '<leader>fb', function() metascope.buffers() end, { desc = "Buffers" })

-- 2. The Atuin-style history dashboard (all types)
vim.keymap.set('n', '<leader>fh', function() metascope.history_picker() end, { desc = "Telescope history" })

-- 3. Hybrid files + frecency history
vim.keymap.set('n', '<leader>fo', function() metascope.hybrid() end, { desc = "Hybrid files + history" })
```

Inside the standard pickers, press your configured key (e.g. `J` in normal mode) to open history **for that picker only**.

```lua
-- Optional: manual builtin wrap (keep default Telescope prompt titles for auto-detect)
-- local builtin = require('telescope.builtin')
-- vim.keymap.set('n', '<leader>ff', function()
--     builtin.find_files(metascope.enrich_opts("files", { hidden = true }))
-- end)
```

Custom pickers: pass `metascope_type` in opts or use `metascope.enrich_opts("files", opts)`.

`:Metascope` opens all history; `:Metascope files` filters by type. Telescope extension: `:Telescope metascope history`.
