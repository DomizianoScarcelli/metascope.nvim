local actions_state = require("telescope.actions.state")
local state = require("metascope.state")

local M = {}

local TITLE_EXTRAS = {
  files = { "find files", "git files", "oldfiles" },
  grep = { "live grep", "grep string", "grep" },
  buffers = { "buffers", "buffer" },
}

function M.build_patterns()
  state._detect_patterns = {}

  for type_name, config in pairs(state.type_config) do
    if type_name ~= "default" then
      local patterns = { type_name }
      if config.label and config.label ~= "" then
        local label = config.label:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
        table.insert(patterns, label)
      end
      if config.builtin then
        table.insert(patterns, config.builtin:lower())
        table.insert(patterns, config.builtin:gsub("_", " "):lower())
      end
      state._detect_patterns[type_name] = patterns
    end
  end

  for type_name, more in pairs(TITLE_EXTRAS) do
    if state._detect_patterns[type_name] then
      for _, pat in ipairs(more) do
        table.insert(state._detect_patterns[type_name], pat)
      end
    end
  end
end

function M.search_type(prompt_bufnr)
  local picker = actions_state.get_current_picker(prompt_bufnr)
  if not picker then
    return "default"
  end

  if picker._metascope_type then
    return picker._metascope_type
  end

  if picker._opts and picker._opts.metascope_type then
    return picker._opts.metascope_type
  end

  local title = (picker.prompt_title or ""):lower()
  if title == "" then
    return "default"
  end

  if not state._detect_patterns then
    M.build_patterns()
  end

  local best_type, best_len = nil, 0
  for type_name, patterns in pairs(state._detect_patterns) do
    for _, pattern in ipairs(patterns) do
      if pattern ~= "" and title:find(pattern, 1, true) then
        local len = #pattern
        if len > best_len then
          best_len = len
          best_type = type_name
        end
      end
    end
  end

  return best_type or "default"
end

return M
