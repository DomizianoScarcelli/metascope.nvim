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
      icon = " ",
      label = "Misc",
      builtin = "find_files",
      opts = {},
    },
  }
end

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults), opts or {})

  state.max_history = opts.max_history
  state.picker_history_keymap = opts.picker_history_keymap
  state.picker_history_keymap_mode = opts.picker_history_keymap_mode
  state.type_config = vim.tbl_deep_extend("force", default_type_config(), opts.type_config or {})

  detect.build_patterns()
  history.load()
  command.register()
end

return M
