local state = require("metascope.state")
local config = require("metascope.config")
local detect = require("metascope.detect")
local history = require("metascope.history")
local history_picker = require("metascope.history_picker")
local hybrid = require("metascope.hybrid")
local mappings = require("metascope.mappings")
local pickers = require("metascope.pickers")

local M = setmetatable({}, { __index = state })

M.setup = config.setup
M.register_type = config.register_type
M.load_history = history.load
M.save_history = history.save
M.flush_history = history.flush_sync
M.get_last_search = history.get_last
M.build_detect_patterns = detect.build_patterns
M.detect_search_type = detect.search_type
M.enrich_opts = pickers.enrich_opts
M.track = pickers.track
M.find_files = pickers.find_files
M.live_grep = pickers.live_grep
M.buffers = pickers.buffers
M.open_history_from_picker = mappings.open_history_from_picker
M.make_attach_save_prompt = mappings.attach_save_prompt
M.history_picker = history_picker.open
M.hybrid = hybrid.files
M.hybrid_files = hybrid.files
M.hybrid_grep = hybrid.grep

-- Zero-config: apply defaults on first require so `:Metascope` and the wrappers
-- work without an explicit setup(). Guarded so a later user setup() doesn't
-- re-run side effects (history is loaded once; the command registers once).
if not state._autoconfigured then
  state._autoconfigured = true
  config.setup({})
end

return M
