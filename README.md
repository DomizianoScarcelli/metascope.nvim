# metascope.nvim 🔭

An Atuin-style, visual, searchable, cross-session prompt history for Telescope.

Standard Telescope history plugins function like bash history: you hit up/down arrows blindly. **Metascope** creates a unified dashboard of your past searches (files, grep, buffers) complete with deduplication, timestamps, and an executing live-preview of the results *before* you even hit enter.

## ✨ Features
- **Visual History Dashboard**: Search through your previous Telescope queries.
- **Zero-Dependency Persistence**: Saves history across sessions using Neovim's native JSON encoding. No SQLite required.
- **Live Terminal Preview**: Automatically runs `rg` or `fd` in the background as you hover over past searches, previewing the results instantly.
- **Smart Deduplication**: Moves repeated searches to the top with a fresh timestamp.

## 📦 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "DomizianoScarcelli/metascope.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        require("metascope").setup({
            max_history = 10000, -- Maximum number of entries to save
        })
    end
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
    "DomizianoScarcelli/metascope.nvim",
    requires = { "nvim-telescope/telescope.nvim" },
    config = function()
        require("metascope").setup({
            max_history = 10000, -- Maximum number of entries to save
        })
    end
}
```

## 🚀 Usage & Keymaps
```lua
local builtin = require('telescope.builtin')
local metascope = require("metascope")

-- 1. The Atuin-Style History Dashboard
vim.keymap.set('n', '<leader>fh', function() metascope.history_picker() end, { desc = "All Telescope History" })
-- You can also filter it! 
-- metascope.history_picker({ types = "files" })
-- metascope.history_picker({ types = { "files", "grep" } })

-- 2. Find Files (Wrapped)
vim.keymap.set('n', '<leader>ff', function()
    builtin.find_files({
        prompt_title = "Find Files",
        default_text = metascope.get_last_search("files"),
        attach_mappings = metascope.make_attach_save_prompt("files"),
        hidden = true,
    })
end, { desc = "Find files (Defaults to last file search)" })

-- 3. Live Grep (Wrapped)
vim.keymap.set('n', '<leader>fg', function()
    builtin.live_grep({
        prompt_title = "Live Grep",
        default_text = metascope.get_last_search("grep"),
        attach_mappings = metascope.make_attach_save_prompt("grep"),
    })
end, { desc = "Live grep (Defaults to last grep)" })
```
