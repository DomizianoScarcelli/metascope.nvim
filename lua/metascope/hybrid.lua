-- Hybrid picker: blends frecency-ranked file history (the destinations you've
-- opened before) with a live listing of every file in the project, in one buffer.
--   * empty prompt  -> your recents only (instant; nothing scanned yet)
--   * start typing   -> the full file list, with frecent files biased to the top
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local actions_set = require("telescope.actions.set")
local conf = require("telescope.config").values

local history = require("metascope.history")
local state = require("metascope.state")

local M = {}

local DEFAULTS = {
  source_types = { "files", "buffers" }, -- history types that resolve to a file
  frecency_bonus = 8, -- how strongly frecency biases ranking while typing
  show_all_on_empty = false, -- empty prompt: recents only (false) or whole tree (true)
  cwd_only = true, -- only surface recents from the current project
  find_command = nil, -- override the file-listing command (list of args)
}

local function resolve_cfg(opts)
  return vim.tbl_extend("force", vim.deepcopy(DEFAULTS), state.hybrid or {}, opts.hybrid or {})
end

local function list_command(cfg)
  if cfg.find_command then
    return cfg.find_command
  end
  if vim.fn.executable("fd") == 1 then
    return { "fd", "--type", "f", "--hidden", "--exclude", ".git" }
  elseif vim.fn.executable("fdfind") == 1 then
    return { "fdfind", "--type", "f", "--hidden", "--exclude", ".git" }
  elseif vim.fn.executable("rg") == 1 then
    return { "rg", "--files", "--hidden", "--glob", "!.git/*" }
  end
  return { "find", ".", "-type", "f", "-not", "-path", "*/.git/*" }
end

local function list_files(cfg)
  local raw = vim.fn.systemlist(list_command(cfg))
  if vim.v.shell_error ~= 0 then
    return {}
  end
  local files = {}
  for _, rel in ipairs(raw) do
    if rel ~= "" then
      files[#files + 1] = vim.fn.fnamemodify(rel, ":p")
    end
  end
  return files
end

-- File destinations from history, deduped by path and frecency-ranked.
local function gather_recents(cfg)
  local cwd = vim.fn.getcwd()
  local now = os.time()
  local seen, out = {}, {}
  for _, e in ipairs(state.telescope_history) do
    if e.target and e.target.path and vim.tbl_contains(cfg.source_types, e.type) then
      if (not cfg.cwd_only) or e.cwd == cwd then
        local p = e.target.path
        if not seen[p] and vim.fn.filereadable(p) == 1 then
          seen[p] = true
          out[#out + 1] = {
            path = p,
            recent = true,
            score = history.score(e, now, cwd),
            count = e.count or 1,
          }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    return a.score > b.score
  end)
  return out, seen
end

local function merge(recents, recent_paths, files)
  local out = {}
  for _, r in ipairs(recents) do
    out[#out + 1] = r
  end
  for _, p in ipairs(files) do
    if not recent_paths[p] then
      out[#out + 1] = { path = p, recent = false }
    end
  end
  return out
end

-- Memoize by raw-table identity: the dynamic finder re-maps every result on each
-- keystroke, but the raw tables are stable, so we build each entry only once.
local function make_entry_maker()
  local cache = setmetatable({}, { __mode = "k" })
  return function(raw)
    local cached = cache[raw]
    if cached then
      return cached
    end
    local rel = vim.fn.fnamemodify(raw.path, ":~:.")
    local display
    if raw.recent then
      display = "★ " .. rel
      if raw.count and raw.count > 1 then
        display = display .. "  (" .. raw.count .. "×)"
      end
    else
      display = "  " .. rel
    end
    local entry = {
      value = raw,
      path = raw.path,
      filename = raw.path,
      display = display,
      ordinal = rel,
    }
    cache[raw] = entry
    return entry
  end
end

-- The default file sorter, but frecent files get their score divided down (lower
-- is better in telescope), so a frecent file beats a cold one on an equal match.
local function frecency_sorter(opts, cfg)
  local sorter = conf.file_sorter(opts)
  local orig = sorter.scoring_function
  sorter.scoring_function = function(self, prompt, line, entry, ...)
    local score = orig(self, prompt, line, entry, ...)
    if not score or score == -1 then
      return score
    end
    local v = entry and entry.value
    if v and v.recent then
      local bonus = (v.score or 1) * (cfg.frecency_bonus or 8)
      score = score / (1 + bonus)
    end
    return score
  end
  return sorter
end

function M.files(opts)
  opts = opts or {}
  local cfg = resolve_cfg(opts)

  local recents, recent_paths = gather_recents(cfg)
  local cached_files, merged

  local finder = finders.new_dynamic({
    entry_maker = make_entry_maker(),
    fn = function(prompt)
      if (prompt == nil or prompt == "") and not cfg.show_all_on_empty then
        return recents
      end
      if cached_files == nil then
        cached_files = list_files(cfg) -- one shot, on first keystroke
        merged = merge(recents, recent_paths, cached_files)
      end
      return merged
    end,
  })

  pickers.new(opts, {
    prompt_title = opts.prompt_title or "Files (metascope)",
    finder = finder,
    sorter = frecency_sorter(opts, cfg),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, _)
      actions_set.select:replace(function()
        local entry = actions_state.get_selected_entry()
        local prompt = actions_state.get_current_line()
        actions.close(prompt_bufnr)
        if not entry then
          return
        end
        local path = entry.path or (entry.value and entry.value.path)
        if not path then
          return
        end
        -- Reinforce frecency: opening a file here records it like find_files does.
        history.push(prompt or "", "files", { path = vim.fn.fnamemodify(path, ":p") })
        vim.schedule(function()
          vim.cmd("edit " .. vim.fn.fnameescape(path))
        end)
      end)
      return true
    end,
  }):find()
end

return M
