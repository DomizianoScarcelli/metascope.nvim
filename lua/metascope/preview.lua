local previewers = require("telescope.previewers")
local state = require("metascope.state")

local M = {}

local function preview_command(entry_value)
  if not entry_value.prompt or entry_value.prompt == "" then
    return { "echo", "Empty prompt" }
  end

  if entry_value.type == "grep" then
    local config = state.type_config.grep
    local cmd = vim.deepcopy(config.opts.vimgrep_arguments)
    for i, v in ipairs(cmd) do
      if v == "--color=never" then
        cmd[i] = "--color=always"
      end
    end
    table.insert(cmd, entry_value.prompt)
    return cmd
  end

  if entry_value.type == "files" then
    if vim.fn.executable("fd") == 1 then
      return { "fd", "--type", "f", "--hidden", "--color=always", entry_value.prompt }
    end
    return { "rg", "--files", "--hidden", "--color=always", "-g", "*" .. entry_value.prompt .. "*" }
  end

  return { "echo", "Preview not configured for type: " .. entry_value.type }
end

M.previewer = previewers.new_termopen_previewer({
  get_command = function(entry, _)
    return preview_command(entry.value)
  end,
  title = "Live Results Preview",
})

return M
