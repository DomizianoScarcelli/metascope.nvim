local previewers = require("telescope.previewers")
local state = require("metascope.state")

local M = {}

-- Show the actual destination we recorded. No repo-wide re-scan on every hover.
local function file_preview(target)
  if vim.fn.filereadable(target.path) ~= 1 then
    return { "echo", "File no longer exists: " .. target.path }
  end
  if vim.fn.executable("bat") == 1 then
    local cmd = { "bat", "--style=numbers", "--color=always", "--paging=never" }
    if target.lnum then
      table.insert(cmd, "--highlight-line")
      table.insert(cmd, tostring(target.lnum))
    end
    table.insert(cmd, target.path)
    return cmd
  end
  return { "cat", target.path }
end

-- Query-only entries (no destination recorded): re-run the search live.
local function search_preview(entry_value)
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

  return { "echo", "Preview not configured for type: " .. tostring(entry_value.type) }
end

local function preview_command(entry_value)
  if entry_value.target and entry_value.target.path then
    return file_preview(entry_value.target)
  end
  if not entry_value.prompt or entry_value.prompt == "" then
    return { "echo", "No preview available" }
  end
  return search_preview(entry_value)
end

M.previewer = previewers.new_termopen_previewer({
  get_command = function(entry, _)
    return preview_command(entry.value)
  end,
  title = "Live Results Preview",
})

return M
