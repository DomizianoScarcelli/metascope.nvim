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
  local results = {}
  for _, entry in ipairs(state.telescope_history) do
    if not filter_types then
      table.insert(results, entry)
    elseif type(filter_types) == "string" and entry.type == filter_types then
      table.insert(results, entry)
    elseif type(filter_types) == "table" and vim.tbl_contains(filter_types, entry.type) then
      table.insert(results, entry)
    end
  end

  -- Frecency order: the most useful row is usually already at the top, so you
  -- often don't need to search at all.
  local now = os.time()
  local cwd = vim.fn.getcwd()
  table.sort(results, function(a, b)
    return history.score(a, now, cwd) > history.score(b, now, cwd)
  end)
  return results
end

-- Re-run the original search (the old behaviour), e.g. to keep exploring a grep.
local function resume_search(entry)
  local config = state.type_config[entry.type] or state.type_config.default
  local resume_opts = pickers_mod.enrich_opts(entry.type, vim.deepcopy(config.opts or {}))
  resume_opts.prompt_title = (config.label or "Search") .. " (Resumed)"
  resume_opts.default_text = entry.prompt

  if type(config.resume) == "function" then
    config.resume(resume_opts)
    return
  end
  local builtin_fn = require("telescope.builtin")[config.builtin]
  if builtin_fn then
    builtin_fn(resume_opts)
  end
end

-- Jump straight to the destination recorded for this entry — one step, no
-- intermediate results list to re-filter.
local function open_target(target)
  if vim.fn.filereadable(target.path) ~= 1 then
    vim.notify("Metascope: file no longer exists: " .. target.path, vim.log.levels.WARN)
    return false
  end
  vim.cmd("edit " .. vim.fn.fnameescape(target.path))
  if target.lnum then
    pcall(vim.api.nvim_win_set_cursor, 0, { target.lnum, math.max(0, (target.col or 1) - 1) })
    vim.cmd("normal! zz")
  end
  return true
end

function M.open(opts)
  opts = opts or {}
  local results = collect_results(opts.types)

  if #results == 0 then
    vim.notify("Metascope: no search history yet", vim.log.levels.INFO)
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
        local label = config.label or "Misc"

        local body
        if entry.prompt and entry.prompt ~= "" then
          body = entry.prompt
        elseif entry.target and entry.target.path then
          body = vim.fn.fnamemodify(entry.target.path, ":~:.")
        else
          body = "(empty)"
        end

        -- "→" marks rows that jump straight to a destination.
        local marker = (entry.target and entry.target.path) and "→ " or "  "
        local display_str = string.format("%s%s%s[%s] %s", time_str, config.icon, marker, label, body)
        return {
          value = entry,
          display = display_str,
          ordinal = (entry.prompt or "") .. " " .. body,
        }
      end,
    }),
    sorter = sorters.get_generic_fuzzy_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions_set.select:replace(function()
        local selection = actions_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not selection then
          return
        end
        local entry = selection.value
        vim.schedule(function()
          if entry.target and entry.target.path then
            if open_target(entry.target) then
              return
            end
          end
          resume_search(entry) -- fallback: no destination recorded, or it vanished
        end)
      end)

      local function resume()
        local selection = actions_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not selection then
          return
        end
        vim.schedule(function()
          resume_search(selection.value)
        end)
      end

      local function delete_entry()
        local current_picker = actions_state.get_current_picker(prompt_bufnr)
        local selection = actions_state.get_selected_entry()
        if not selection then
          return
        end
        local id = history.identity(selection.value)
        history.remove(selection.value)
        current_picker:delete_selection(function(sel)
          return history.identity(sel.value) == id
        end)
      end

      if state.resume_keymap then
        map("i", state.resume_keymap, resume)
        map("n", state.resume_keymap, resume)
      end
      map("i", "<C-d>", delete_entry)
      map("n", "dd", delete_entry)

      return true
    end,
  }):find()
end

return M
