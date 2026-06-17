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

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults), opts or {})

  state.max_history = opts.max_history
  state.picker_history_keymap = opts.picker_history_keymap
  state.picker_history_keymap_mode = opts.picker_history_keymap_mode
  state.resume_keymap = opts.resume_keymap
  state.cwd_boost = opts.cwd_boost
  state.half_life_days = opts.half_life_days
  state.save_debounce_ms = opts.save_debounce_ms
  state.type_config = vim.tbl_deep_extend("force", default_type_config(), opts.type_config or {})

  detect.build_patterns()
  history.load()
  command.register()
  ensure_autocmds()
end

return M
