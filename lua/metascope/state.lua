local M = {}

M.defaults = {
  max_history = 10000,
  picker_history_keymap = "J",
  picker_history_keymap_mode = "n",
  -- In the history dashboard: re-run the search instead of jumping to the
  -- destination you opened last time. Set to false to disable.
  resume_keymap = "<C-r>",
  -- Frecency tuning.
  cwd_boost = 4, -- multiplier for entries created in the current project (cwd)
  half_life_days = 3, -- recency half-life: an entry's recency weight halves every N days
  -- Persistence.
  save_debounce_ms = 1000, -- coalesce rapid writes into one async flush
  -- Hybrid picker: live files blended with frecency-ranked file history.
  hybrid = {
    source_types = { "files", "buffers" }, -- history types that resolve to a file
    frecency_bonus = 8, -- how strongly frecency biases ranking while typing
    show_all_on_empty = false, -- empty prompt: recents only (false) or whole tree (true)
    cwd_only = true, -- only surface recents from the current project
    find_command = nil, -- override the file-listing command (list of args)
  },
  -- Keymaps: false (set none), true (recommended <leader>ff/fh/fo), or a table
  -- { find_files = "<lhs>", history = "<lhs>", hybrid = "<lhs>" } (any may be false).
  keymaps = false,
}

M.history_file = vim.fn.stdpath("data") .. "/telescope_metascope_history.json"
M.max_history = M.defaults.max_history
M.telescope_history = {}
M.type_config = {}
M.picker_history_keymap = M.defaults.picker_history_keymap
M.picker_history_keymap_mode = M.defaults.picker_history_keymap_mode
M.resume_keymap = M.defaults.resume_keymap
M.cwd_boost = M.defaults.cwd_boost
M.half_life_days = M.defaults.half_life_days
M.save_debounce_ms = M.defaults.save_debounce_ms
M.hybrid = vim.deepcopy(M.defaults.hybrid)
M.keymaps = M.defaults.keymaps

M._detect_patterns = nil
M._loaded = false
M._command_registered = false
M._autocmds_registered = false
M._autoconfigured = false

return M
