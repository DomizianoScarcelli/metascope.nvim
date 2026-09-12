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
local ui = require("metascope.ui")

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

  -- One row per place: "init" -> init.lua and "ini" -> init.lua are the same
  -- destination to the user, so they collapse (visit counts add up).
  local now = os.time()
  local cwd = vim.fn.getcwd()
  results = history.collapse_by_destination(results, now, cwd)

  -- Frecency order: the most useful row is usually already at the top, so you
  -- often don't need to search at all.
  table.sort(results, function(a, b)
    return history.score(a, now, cwd) > history.score(b, now, cwd)
  end)
  return results
end

-- Type filters you can Tab through in the dashboard: all, then each known type.
local function filter_cycle()
  local names = {}
  for name in pairs(state.type_config) do
    if name ~= "default" then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  table.insert(names, 1, "all")
  return names
end

-- Next filter after `current` that actually has entries (empty types are skipped).
local function next_filter(current)
  local cycle = filter_cycle()
  local cur = type(current) == "string" and current or "all"
  local start = 1
  for i, name in ipairs(cycle) do
    if name == cur then
      start = i
      break
    end
  end
  for k = 1, #cycle - 1 do
    local name = cycle[((start - 1 + k) % #cycle) + 1]
    if name == "all" then
      return nil
    end
    if #history.filter_by_type(name) > 0 then
      return name
    end
  end
  return nil
end

-- Re-run the original search, e.g. to keep exploring a grep. files/grep reopen
-- as the hybrid pickers (so recents stay pinned); other types use their builtin
-- or the `resume` function registered for them.
function M.resume_search(entry)
  local config = state.type_config[entry.type] or state.type_config.default
  local resume_opts = vim.deepcopy(config.opts or {})
  resume_opts.default_text = entry.prompt

  if type(config.resume) == "function" then
    config.resume(pickers_mod.enrich_opts(entry.type, resume_opts))
    return
  end
  if entry.type == "files" then
    return pickers_mod.find_files(resume_opts)
  elseif entry.type == "grep" then
    return pickers_mod.live_grep(resume_opts)
  end
  resume_opts = pickers_mod.enrich_opts(entry.type, resume_opts)
  resume_opts.prompt_title = (config.label or "Search") .. " (Resumed)"
  local builtin_fn = require("telescope.builtin")[config.builtin]
  if builtin_fn then
    builtin_fn(resume_opts)
  end
end

-- Jump straight to the destination recorded for this entry — one step, no
-- intermediate results list to re-filter. Counts as a visit (frecency) and
-- keeps following the cursor so the next jump lands where you leave off.
local function open_target(entry)
  local target = entry.target
  if vim.fn.filereadable(target.path) ~= 1 then
    vim.notify("Metascope: file no longer exists: " .. target.path, vim.log.levels.WARN)
    return false
  end
  local recorded = history.push(entry.prompt or "", entry.type, vim.deepcopy(target))
  vim.cmd("edit " .. vim.fn.fnameescape(target.path))
  if target.lnum then
    pcall(vim.api.nvim_win_set_cursor, 0, { target.lnum, math.max(0, (target.col or 1) - 1) })
    vim.cmd("normal! zz")
  end
  history.track_cursor(vim.api.nvim_get_current_buf(), recorded)
  return true
end

function M.open(opts)
  opts = opts or {}
  local results = collect_results(opts.types)

  if #results == 0 then
    vim.notify("Metascope: no search history yet", vim.log.levels.INFO)
    return
  end

  local filter_name = type(opts.types) == "string" and opts.types or nil
  local base_title = "History" .. (filter_name and (" · " .. filter_name) or "")
  local now = os.time()

  pickers.new(opts, {
    prompt_title = base_title .. " · Tab filter",
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
        local rel = entry.time and ui.relative_time(entry.time, now) or (entry.timestamp or "")
        local time_str = rel ~= "" and string.format("%-9s ", rel) or ""
        local label = config.label or "Misc"

        -- The file (and, for grep, the line) this search opened last time, if any.
        local file_str = ""
        if entry.target and entry.target.path then
          file_str = vim.fn.fnamemodify(entry.target.path, ":~:.")
          if entry.type == "grep" and entry.target.lnum then
            file_str = file_str .. ":" .. entry.target.lnum
          end
        end
        local visits = entry.merged_count or entry.count or 1

        -- Show the query and, when known, the file it took you to (with its filetype icon).
        local parts = {
          { time_str, "TelescopeResultsComment" },
          { config.icon .. "[" .. label .. "] ", "TelescopeResultsIdentifier" },
        }
        local icon, icon_hl = "", nil
        if file_str ~= "" then
          icon, icon_hl = ui.file_icon(entry.target.path, opts)
        end
        if entry.prompt and entry.prompt ~= "" then
          parts[#parts + 1] = { entry.prompt }
          if file_str ~= "" then
            parts[#parts + 1] = { "  → ", "TelescopeResultsComment" }
            parts[#parts + 1] = { icon, icon_hl }
            parts[#parts + 1] = { file_str, "TelescopeResultsComment" }
          end
        elseif file_str ~= "" then
          parts[#parts + 1] = { "→ ", "TelescopeResultsComment" }
          parts[#parts + 1] = { icon, icon_hl }
          parts[#parts + 1] = { file_str }
        else
          parts[#parts + 1] = { "(empty)", "TelescopeResultsComment" }
        end
        if visits > 1 then
          parts[#parts + 1] = { "  (" .. visits .. "×)", "TelescopeResultsComment" }
        end

        return {
          value = entry,
          display = ui.display(parts),
          -- match on both the query and the filename when fuzzy-searching history
          ordinal = (entry.prompt or "") .. " " .. file_str,
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
            if open_target(entry) then
              return
            end
          end
          M.resume_search(entry) -- fallback: no destination recorded, or it vanished
        end)
      end)

      local function resume()
        local selection = actions_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not selection then
          return
        end
        vim.schedule(function()
          M.resume_search(selection.value)
        end)
      end

      -- Tab: cycle the type filter (all -> buffers -> files -> grep -> all ...),
      -- keeping whatever you've typed.
      local function cycle_filter()
        local current_prompt = actions_state.get_current_line() or ""
        local nxt = next_filter(opts.types)
        actions.close(prompt_bufnr)
        vim.schedule(function()
          M.open(vim.tbl_extend("force", opts, { types = nxt, default_text = current_prompt }))
        end)
      end
      map("i", "<Tab>", cycle_filter)
      map("n", "<Tab>", cycle_filter)

      local function delete_entry()
        local current_picker = actions_state.get_current_picker(prompt_bufnr)
        local selection = actions_state.get_selected_entry()
        if not selection then
          return
        end
        local id = history.identity(selection.value)
        history.remove_destination(selection.value)
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
