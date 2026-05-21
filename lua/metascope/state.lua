local M = {}

M.defaults = {
  max_history = 10000,
  picker_history_keymap = "J",
  picker_history_keymap_mode = "n",
}

M.history_file = vim.fn.stdpath("data") .. "/telescope_metascope_history.json"
M.max_history = M.defaults.max_history
M.telescope_history = {}
M.type_config = {}
M.picker_history_keymap = M.defaults.picker_history_keymap
M.picker_history_keymap_mode = M.defaults.picker_history_keymap_mode
M._detect_patterns = nil
M.cycle_index = nil

return M
