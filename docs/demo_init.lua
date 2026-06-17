-- Minimal Neovim config used only to record the demo GIF (see docs/demo.tape).
-- It loads Telescope + metascope from your packer install and seeds a little
-- history so the pickers have something to show. Run from the repo root:
--   nvim -u docs/demo_init.lua

local pack = vim.fn.stdpath("data") .. "/site/pack/packer/start"
for _, p in ipairs({ "plenary.nvim", "telescope.nvim", "metascope.nvim" }) do
  vim.opt.runtimepath:append(pack .. "/" .. p)
end
-- also load the checkout we're sitting in, so it records the local version
vim.opt.runtimepath:prepend(vim.fn.getcwd())

vim.o.number = true
vim.o.termguicolors = true
vim.o.laststatus = 0
vim.o.cmdheight = 0
vim.g.mapleader = " "
pcall(function()
  vim.cmd.colorscheme("habamax")
end)

local ok_ts, telescope = pcall(require, "telescope")
if not ok_ts then
  error("demo: telescope not found on runtimepath — install it via your plugin manager first")
end
telescope.setup({ defaults = { layout_config = { horizontal = { preview_width = 0.55 } } } })

-- Use a throwaway history file so recording the demo never touches your real
-- history. Must be set before `require("metascope")` (which auto-loads history).
require("metascope.state").history_file = vim.fn.tempname()

local metascope = require("metascope")
metascope.setup({ keymaps = true })

-- Seed some history so the dashboard / recents aren't empty in the recording.
local history = require("metascope.history")
local cwd = vim.fn.getcwd()
local function seed(prompt, kind, file, lnum)
  local target = file and { path = cwd .. "/" .. file, lnum = lnum } or nil
  history.push(prompt, kind, target)
end
seed("preview", "files", "lua/metascope/preview.lua")
seed("hybrid", "files", "lua/metascope/hybrid.lua")
seed("history", "files", "lua/metascope/history.lua")
seed("history", "files", "lua/metascope/history.lua") -- bump frecency
seed("frecency", "grep", "lua/metascope/history.lua", 24)
seed("function M", "grep", "lua/metascope/init.lua", 11)

-- Clean commands for the demo recording (unambiguous under vhs, no leader timing).
vim.api.nvim_create_user_command("Files", function() metascope.hybrid() end, {})
vim.api.nvim_create_user_command("Grep", function() metascope.hybrid_grep() end, {})
vim.api.nvim_create_user_command("History", function() metascope.history_picker() end, {})
