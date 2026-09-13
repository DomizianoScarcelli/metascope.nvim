-- Minimal Neovim config used only to record the demo clips (see docs/*.tape).
-- Loads Telescope (+ devicons) from your plugin manager's install dir and this
-- checkout of metascope, with a throwaway, seeded history. Run from the repo root:
--   nvim --clean -u docs/demo_init.lua

local data = vim.fn.stdpath("data")
local function add(p)
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.runtimepath:append(p)
    return true
  end
end
for _, name in ipairs({ "plenary.nvim", "telescope.nvim", "nvim-web-devicons" }) do
  local _ = add(data .. "/lazy/" .. name) or add(data .. "/site/pack/packer/start/" .. name)
end
-- the checkout we're sitting in, so the recording shows the local version
vim.opt.runtimepath:prepend(vim.fn.getcwd())

vim.o.number = true
vim.o.swapfile = false
vim.o.termguicolors = true
vim.o.laststatus = 0
vim.o.cmdheight = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.fillchars = "eob: "
vim.g.mapleader = " "
pcall(vim.cmd.colorscheme, "habamax")

local ok_ts, telescope = pcall(require, "telescope")
if not ok_ts then
  error("demo: telescope not found on runtimepath — install it via your plugin manager first")
end
telescope.setup({ defaults = { layout_config = { horizontal = { preview_width = 0.5 } } } })
pcall(function()
  require("nvim-web-devicons").setup({})
end)

-- Throwaway history file so recording never touches your real history.
-- Must be set before `require("metascope")` (which auto-loads history).
require("metascope.state").history_file = vim.fn.tempname()

local metascope = require("metascope")
metascope.setup({ keymaps = true })

-- Seed history with a spread of ages so the dashboard shows "2h ago" etc.
local history = require("metascope.history")
local state = require("metascope.state")
local cwd = vim.fn.getcwd()
local now = os.time()
local function seed(prompt, kind, file, lnum, age_h, count)
  local target = file and { path = cwd .. "/" .. file, lnum = lnum, col = 1 } or nil
  local e = history.push(prompt, kind, target)
  e.time = now - math.floor((age_h or 0) * 3600)
  e.count = count or 1
end
seed("", "files", "lua/metascope/history.lua", 68, 0.05, 6) -- 3m ago, visited a lot
seed("hybrid", "files", "lua/metascope/hybrid.lua", 167, 2, 3)
seed("preview", "files", "lua/metascope/preview.lua", 30, 5, 2)
seed("readme", "files", "README.md", 7, 26, 1)
seed("frecency", "grep", "lua/metascope/history.lua", 66, 1, 4)
seed("function M", "grep", "lua/metascope/init.lua", 11, 30, 2)
seed("attach_mappings", "grep", "lua/metascope/hybrid.lua", 189, 50, 1)
table.sort(state.telescope_history, function(a, b)
  return a.time > b.time
end)

-- Title card between scenes: a centered float that explains what comes next.
local card
vim.api.nvim_create_user_command("Caption", function(o)
  if card and vim.api.nvim_win_is_valid(card) then
    vim.api.nvim_win_close(card, true)
  end
  local lines = vim.split(o.args, "|", { plain = true })
  local width = 0
  for i, l in ipairs(lines) do
    lines[i] = "  " .. vim.trim(l) .. "  "
    width = math.max(width, vim.fn.strdisplaywidth(lines[i]))
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  card = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2) - 2,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
  vim.api.nvim_set_hl(0, "DemoCard", { fg = "#1e1e2e", bg = "#cba6f7", bold = true })
  vim.api.nvim_set_hl(0, "DemoCardBorder", { fg = "#cba6f7", bg = "#cba6f7" })
  vim.wo[card].winhighlight = "Normal:DemoCard,FloatBorder:DemoCardBorder"
end, { nargs = 1 })
vim.api.nvim_create_user_command("Uncaption", function()
  if card and vim.api.nvim_win_is_valid(card) then
    vim.api.nvim_win_close(card, true)
  end
  card = nil
end, {})

-- Unambiguous commands for vhs (no leader timing).
vim.api.nvim_create_user_command("Files", function() metascope.find_files() end, {})
vim.api.nvim_create_user_command("Grep", function() metascope.live_grep() end, {})
vim.api.nvim_create_user_command("History", function() metascope.history_picker() end, {})
vim.api.nvim_create_user_command("Last", function() metascope.resume_last() end, {})
