local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local actions_set = require("telescope.actions.set")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")

local history = require("metascope.history")
local pickers_mod = require("metascope.pickers")
local preview = require("metascope.preview")
local state = require("metascope.state")

local M = {}

local function collect_results(filter_types)
  if not filter_types then
    return state.telescope_history
  end

  local results = {}
  for _, entry in ipairs(state.telescope_history) do
    if type(filter_types) == "string" and entry.type == filter_types then
      table.insert(results, entry)
    elseif type(filter_types) == "table" and vim.tbl_contains(filter_types, entry.type) then
      table.insert(results, entry)
    end
  end
  return results
end

function M.open(opts)
  opts = opts or {}
  local results = collect_results(opts.types)

  if #results == 0 then
    print("No search history found!")
    return
  end

  pickers.new(opts, {
    prompt_title = "Telescope History",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        mirror = false,
        preview_width = 0.55,
      },
    },
    previewer = preview.previewer,
    finder = finders.new_table({
      results = results,
      entry_maker = function(entry)
        local config = state.type_config[entry.type] or state.type_config.default
        local time_str = entry.timestamp and ("[" .. entry.timestamp .. "] ") or ""
        local display_str = string.format("%s%s[%s] %s", time_str, config.icon, config.label, entry.prompt)
        return { value = entry, display = display_str, ordinal = display_str }
      end,
    }),
    sorter = sorters.get_generic_fuzzy_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions_set.select:replace(function(_, _)
        local selection = actions_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if not selection then
          return
        end

        vim.defer_fn(function()
          local entry = selection.value
          local config = state.type_config[entry.type] or state.type_config.default
          local builtin_fn = require("telescope.builtin")[config.builtin]

          if not builtin_fn then
            return
          end

          local resume_opts = pickers_mod.enrich_opts(entry.type, vim.deepcopy(config.opts))
          resume_opts.prompt_title = config.label .. " (Resumed)"
          resume_opts.default_text = entry.prompt
          builtin_fn(resume_opts)
        end, 50)
      end)

      local function delete_entry()
        local current_picker = actions_state.get_current_picker(prompt_bufnr)
        local selection = actions_state.get_selected_entry()
        if not selection then
          return
        end

        history.remove(selection.value.prompt, selection.value.type)

        current_picker:delete_selection(function(sel)
          return sel.value.prompt == selection.value.prompt
        end)
      end

      map("i", "<C-d>", delete_entry)
      map("n", "dd", delete_entry)

      return true
    end,
  }):find()
end

return M
