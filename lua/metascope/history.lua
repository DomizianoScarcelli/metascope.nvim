local state = require("metascope.state")

local M = {}

local uv = vim.uv or vim.loop

-- Identity used for de-duplication, merge and removal.
--   * a typed query  -> keyed on (type, cwd, prompt)
--   * a bare pick     -> keyed on (type, cwd, destination path) so e.g. selecting
--     several buffers (empty prompt) records one row per file instead of collapsing.
--     The line is deliberately not part of the key: the cursor position is
--     updated as you move around the file (see track_cursor) and must not fork
--     the entry.
function M.identity(entry)
  local key = entry.prompt
  if (not key or key == "") and entry.target and entry.target.path then
    key = "@" .. entry.target.path
  end
  return table.concat({ entry.type or "", entry.cwd or "", key or "" }, "\0")
end

-- Destination identity: rows that end up in the same place (same type, cwd and
-- file, plus line for grep) are one "place" to the user even if they were reached
-- through different queries. Used by the dashboard to collapse duplicates.
function M.destination(entry)
  local t = entry.target
  if not t or not t.path then
    return nil
  end
  local lnum = entry.type == "grep" and t.lnum or nil
  return table.concat({ entry.type or "", entry.cwd or "", t.path, tostring(lnum or "") }, "\0")
end

-- Collapse a list of entries by destination, keeping the best-scored row and
-- summing visit counts. Entries without a destination pass through untouched.
function M.collapse_by_destination(entries, now, cwd)
  now = now or os.time()
  local out, by_dest = {}, {}
  for _, e in ipairs(entries) do
    local d = M.destination(e)
    if not d then
      out[#out + 1] = e
    else
      local kept = by_dest[d]
      if not kept then
        local copy = vim.deepcopy(e)
        copy.merged_count = e.count or 1
        by_dest[d] = copy
        out[#out + 1] = copy
      else
        kept.merged_count = kept.merged_count + (e.count or 1)
        if M.score(e, now, cwd) > M.score(kept, now, cwd) then
          -- take the better row's query/time but keep the accumulated count
          local mc = kept.merged_count
          for k, v in pairs(e) do
            kept[k] = v
          end
          kept.merged_count = mc
        end
      end
    end
  end
  return out
end

-- Frecency: frequency weighted by an exponential recency decay, then boosted
-- when the entry belongs to the project you're currently in. Higher is better.
function M.score(entry, now, cwd)
  now = now or os.time()
  local age_days = math.max(0, (now - (entry.time or now)) / 86400)
  local half_life = state.half_life_days or 3
  local recency = 0.5 ^ (age_days / half_life)
  local freq = entry.count or 1
  local s = freq * recency
  if cwd and entry.cwd == cwd then
    s = s * (state.cwd_boost or 4)
  end
  return s
end

function M.load(force)
  if state._loaded and not force then
    return
  end
  state._loaded = true

  if vim.fn.filereadable(state.history_file) ~= 1 then
    return
  end

  local data = vim.fn.readfile(state.history_file)
  if not data or not data[1] then
    return
  end

  local ok, decoded = pcall(vim.fn.json_decode, data[1])
  if ok and type(decoded) == "table" then
    state.telescope_history = decoded
  end
end

local function trim()
  while #state.telescope_history > state.max_history do
    table.remove(state.telescope_history)
  end
end

-- Fold whatever is currently on disk (possibly written by another nvim instance)
-- back into our in-memory list so concurrent sessions don't clobber each other.
local function merge_disk()
  if vim.fn.filereadable(state.history_file) ~= 1 then
    return
  end
  local data = vim.fn.readfile(state.history_file)
  if not data or not data[1] then
    return
  end
  local ok, disk = pcall(vim.fn.json_decode, data[1])
  if not ok or type(disk) ~= "table" then
    return
  end

  local seen = {}
  for _, e in ipairs(state.telescope_history) do
    seen[M.identity(e)] = e
  end
  for _, e in ipairs(disk) do
    local id = M.identity(e)
    local mine = seen[id]
    if not mine then
      table.insert(state.telescope_history, e)
      seen[id] = e
    else
      if (e.time or 0) > (mine.time or 0) then
        mine.time = e.time
        mine.timestamp = e.timestamp
        mine.prompt = e.prompt
        mine.target = e.target or mine.target
      end
      mine.count = math.max(mine.count or 1, e.count or 1)
    end
  end
end

local function serialize()
  merge_disk()
  -- Newest first, so trimming sheds the stalest rows.
  table.sort(state.telescope_history, function(a, b)
    return (a.time or 0) > (b.time or 0)
  end)
  trim()
  local ok, encoded = pcall(vim.fn.json_encode, state.telescope_history)
  if ok then
    return encoded
  end
  return nil
end

-- Async, non-blocking write. Safe to call off a debounce timer.
function M.flush()
  M._pending = false
  local encoded = serialize()
  if not encoded then
    return
  end
  uv.fs_open(state.history_file, "w", 420, function(err, fd)
    if err or not fd then
      return
    end
    uv.fs_write(fd, encoded, 0, function()
      uv.fs_close(fd)
    end)
  end)
end

-- Blocking write, for shutdown (VimLeavePre) where the event loop won't run again.
function M.flush_sync()
  M._pending = false
  local encoded = serialize()
  if encoded then
    vim.fn.writefile({ encoded }, state.history_file)
  end
end

-- Debounced save: coalesces a burst of selections into a single async write
-- instead of rewriting the whole history file on every <CR>.
function M.save()
  trim()
  M._pending = true
  if M._timer then
    return
  end
  M._timer = uv.new_timer()
  M._timer:start(
    state.save_debounce_ms or 1000,
    0,
    vim.schedule_wrap(function()
      if M._timer then
        M._timer:stop()
        M._timer:close()
        M._timer = nil
      end
      if M._pending then
        M.flush()
      end
    end)
  )
end

-- Most recent entry, optionally restricted to a type and/or the current cwd.
function M.get_last_entry(search_type, cwd)
  local best
  for _, entry in ipairs(state.telescope_history) do
    if (not search_type or entry.type == search_type) and (not cwd or entry.cwd == cwd) then
      if not best or (entry.time or 0) > (best.time or 0) then
        best = entry
      end
    end
  end
  return best
end

function M.get_last(search_type)
  local best = M.get_last_entry(search_type)
  return best and best.prompt or ""
end

-- Record a search. `target` (optional) is the concrete destination the user
-- opened, so the entry can later jump straight back to it.
function M.push(prompt, search_type, target)
  local incoming = {
    prompt = prompt or "",
    type = search_type,
    cwd = vim.fn.getcwd(),
    target = target,
    timestamp = os.date("%m/%d %H:%M"),
    time = os.time(),
    count = 1,
  }
  local id = M.identity(incoming)

  for i, entry in ipairs(state.telescope_history) do
    if M.identity(entry) == id then
      incoming.count = (entry.count or 1) + 1
      incoming.target = target or entry.target -- keep the prior destination if none captured now
      -- A bare file pick has no line; keep the position track_cursor recorded last time.
      local prev = entry.target
      if target and prev and target.path == prev.path and not target.lnum and prev.lnum then
        incoming.target = vim.tbl_extend("force", prev, target)
      end
      table.remove(state.telescope_history, i)
      break
    end
  end

  table.insert(state.telescope_history, 1, incoming)
  M.save()
  return incoming
end

-- Keep `entry.target` pointing at where the cursor last was in `bufnr`, so a
-- later jump back lands where you left off rather than at the top of the file.
-- Updated on every BufLeave (and at exit) for as long as the buffer lives.
function M.track_cursor(bufnr, entry)
  if not entry or not entry.target or not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local group = vim.api.nvim_create_augroup("MetascopeCursor" .. bufnr, { clear = true })
  local function record()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    local win = vim.fn.bufwinid(bufnr)
    if win == -1 then
      return
    end
    local pos = vim.api.nvim_win_get_cursor(win)
    if entry.target.lnum ~= pos[1] or entry.target.col ~= pos[2] + 1 then
      entry.target.lnum = pos[1]
      entry.target.col = pos[2] + 1
      M.save()
    end
  end
  vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, { group = group, buffer = bufnr, callback = record })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = record })
end

function M.remove(entry)
  local id = M.identity(entry)
  for i, e in ipairs(state.telescope_history) do
    if M.identity(e) == id then
      table.remove(state.telescope_history, i)
      M.save()
      return true
    end
  end
  return false
end

-- Remove every entry leading to the same destination as `entry` (a collapsed
-- dashboard row stands for all of them). Falls back to identity removal.
function M.remove_destination(entry)
  local d = M.destination(entry)
  if not d then
    return M.remove(entry)
  end
  local removed = false
  for i = #state.telescope_history, 1, -1 do
    if M.destination(state.telescope_history[i]) == d then
      table.remove(state.telescope_history, i)
      removed = true
    end
  end
  if removed then
    M.save()
  end
  return removed
end

function M.filter_by_type(search_type)
  local filtered = {}
  for _, entry in ipairs(state.telescope_history) do
    if entry.type == search_type then
      table.insert(filtered, entry)
    end
  end
  return filtered
end

return M
