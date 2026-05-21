local state = require("metascope.state")
local config = require("metascope.config")
local detect = require("metascope.detect")
local history = require("metascope.history")
local history_picker = require("metascope.history_picker")
local mappings = require("metascope.mappings")
local pickers = require("metascope.pickers")

local M = setmetatable({}, { __index = state })

M.setup = config.setup
M.load_history = history.load
M.save_history = history.save
M.get_last_search = history.get_last
M.build_detect_patterns = detect.build_patterns
M.detect_search_type = detect.search_type
M.enrich_opts = pickers.enrich_opts
M.find_files = pickers.find_files
M.live_grep = pickers.live_grep
M.buffers = pickers.buffers
M.open_history_from_picker = mappings.open_history_from_picker
M.cycle_history = mappings.cycle_history
M.make_attach_save_prompt = mappings.attach_save_prompt
M.history_picker = history_picker.open

config.setup({})

return M
