local command = require("metascope.command")
local detect = require("metascope.detect")
local history = require("metascope.history")
local state = require("metascope.state")

local M = {}

local function default_type_config()
  return {
    grep = {
      icon = "󰊄 ",
      label = "Grep",
      builtin = "live_grep",
      opts = {
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
        },
      },
    },
    files = {
      icon = "󰈔 ",
      label = "File",
      builtin = "find_files",
      opts = { hidden = true },
    },
    buffers = {
      icon = "󰈙 ",
      label = "Buff",
      builtin = "buffers",
      opts = {},
    },
    default = {
      icon = " ",
      label = "Misc",
      builtin = "find_files",
      opts = {},
    },
  }
end

-- Flush in-memory history to disk synchronously when nvim exits, since the event
-- loop won't run again to drain the debounced async write.
local function ensure_autocmds()
  if state._autocmds_registered then
    return
  end
  state._autocmds_registered = true
  local group = vim.api.nvim_create_augroup("Metascope", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      pcall(history.flush_sync)
    end,
  })
end

-- Register (or override) a search type at runtime. A type may supply either a
-- `builtin` name or a `resume = function(opts)` to re-run custom/extension pickers.
function M.register_type(name, cfg)
  state.type_config[name] = vim.tbl_deep_extend("force", state.type_config[name] or {}, cfg or {})
  detect.build_patterns()
end

-- Entry points the user can bind. find_files/live_grep are the hybrid pickers
-- (history on an empty prompt); `hybrid`/`hybrid_grep` are kept as aliases.
local function apply_keymaps(km)
  if km == true then
    km = {
      find_files = "<leader>ff",
      live_grep = "<leader>fg",
      buffers = "<leader>fb",
      history = "<leader>fh",
      last = "<leader>fl",
      hybrid = "<leader>fo", -- alias of find_files, kept for muscle memory
    }
  end
  if type(km) ~= "table" then
    return km
  end
  local function bind(lhs, fn, desc)
    if lhs then
      vim.keymap.set("n", lhs, fn, { desc = desc, silent = true })
    end
  end
  bind(km.find_files, function()
    require("metascope").find_files()
  end, "Metascope: files (recents on empty prompt)")
  bind(km.live_grep, function()
    require("metascope").live_grep()
  end, "Metascope: grep (recent queries on empty prompt)")
  bind(km.buffers, function()
    require("metascope").buffers()
  end, "Metascope: buffers (history-recording)")
  bind(km.history, function()
    require("metascope").history_picker()
  end, "Metascope: history dashboard")
  bind(km.last, function()
    require("metascope").resume_last()
  end, "Metascope: resume the last search")
  -- backwards-compatible aliases
  bind(km.hybrid, function()
    require("metascope").hybrid()
  end, "Metascope: hybrid files + history")
  bind(km.hybrid_grep, function()
    require("metascope").hybrid_grep()
  end, "Metascope: hybrid grep + history")
  return km
end

function M.setup(opts)
  opts = opts or {}
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults), opts)

  state.max_history = merged.max_history
  state.picker_history_keymap = merged.picker_history_keymap
  state.picker_history_keymap_mode = merged.picker_history_keymap_mode
  state.title_hint = merged.title_hint
  state.resume_keymap = merged.resume_keymap
  state.cwd_boost = merged.cwd_boost
  state.half_life_days = merged.half_life_days
  state.save_debounce_ms = merged.save_debounce_ms
  state.type_config = vim.tbl_deep_extend("force", default_type_config(), opts.type_config or {})
  -- Shallow merge so list options (e.g. source_types) replace cleanly.
  state.hybrid = vim.tbl_extend("force", vim.deepcopy(state.defaults.hybrid), opts.hybrid or {})

  detect.build_patterns()
  history.load()
  command.register()
  ensure_autocmds()
  state.keymaps = apply_keymaps(opts.keymaps)
end

return M
