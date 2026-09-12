local builtin = require("telescope.builtin")
local actions_state = require("telescope.actions.state")

local history = require("metascope.history")
local mappings = require("metascope.mappings")

local M = {}

function M.enrich_opts(search_type, opts)
  opts = vim.deepcopy(opts or {})
  opts.metascope_type = search_type

  if opts.default_text == nil then
    opts.default_text = history.get_last(search_type)
  end

  local user_attach = opts.attach_mappings
  opts.attach_mappings = function(prompt_bufnr, map)
    local picker = actions_state.get_current_picker(prompt_bufnr)
    if picker then
      picker._metascope_type = search_type
    end
    if user_attach then
      local ok = user_attach(prompt_bufnr, map)
      if ok == false then
        return false
      end
    end
    return mappings.attach_save_prompt(search_type)(prompt_bufnr, map)
  end

  return opts
end

-- History is the empty-prompt state of every picker: find_files and live_grep are
-- the hybrid pickers. Pass `hybrid = false` for the plain builtin (still recorded).
function M.find_files(opts)
  opts = opts or {}
  if opts.hybrid == false then
    return builtin.find_files(M.enrich_opts("files", opts))
  end
  return require("metascope.hybrid").files(opts)
end

function M.live_grep(opts)
  opts = opts or {}
  if opts.hybrid == false then
    return builtin.live_grep(M.enrich_opts("grep", opts))
  end
  return require("metascope.hybrid").grep(opts)
end

function M.buffers(opts)
  builtin.buffers(M.enrich_opts("buffers", opts))
end

-- Reopen the last search you made (in this project first, anywhere otherwise)
-- with its query pre-filled. One key to get back to what you were doing.
function M.resume_last(opts)
  local entry = history.get_last_entry(nil, vim.fn.getcwd()) or history.get_last_entry()
  if not entry then
    vim.notify("Metascope: no search history yet", vim.log.levels.INFO)
    return
  end
  opts = vim.tbl_extend("force", { default_text = entry.prompt }, opts or {})
  if entry.type == "files" then
    return M.find_files(opts)
  elseif entry.type == "grep" then
    return M.live_grep(opts)
  elseif entry.type == "buffers" then
    return M.buffers(opts)
  end
  return require("metascope.history_picker").resume_search(entry)
end

-- First-class hook for wrapping any picker (builtin or custom/extension) so it
-- records metascope history. `metascope.track("symbols", opts)` returns enriched
-- opts to pass straight into the underlying picker.
M.track = M.enrich_opts

return M
