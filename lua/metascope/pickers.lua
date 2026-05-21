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

function M.find_files(opts)
  builtin.find_files(M.enrich_opts("files", opts))
end

function M.live_grep(opts)
  builtin.live_grep(M.enrich_opts("grep", opts))
end

function M.buffers(opts)
  builtin.buffers(M.enrich_opts("buffers", opts))
end

return M
