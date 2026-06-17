local state = require("metascope.state")

local M = {}

local uv = vim.uv or vim.loop

-- Identity used for de-duplication, merge and removal.
--   * a typed query  -> keyed on (type, cwd, prompt)
--   * a bare pick     -> keyed on (type, cwd, destination path) so e.g. selecting
--     several buffers (empty prompt) records one row per file instead of collapsing.
function M.identity(entry)
  local key = entry.prompt
  if (not key or key == "") and entry.target and entry.target.path then
    key = "@" .. entry.target.path .. ":" .. tostring(entry.target.lnum or "")
  end
  return table.concat({ entry.type or "", entry.cwd or "", key or "" }, "\0")
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

function M.get_last(search_type)
  local best
  for _, entry in ipairs(state.telescope_history) do
    if entry.type == search_type and (not best or (entry.time or 0) > (best.time or 0)) then
      best = entry
    end
  end
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
      table.remove(state.telescope_history, i)
      break
    end
  end

  table.insert(state.telescope_history, 1, incoming)
  M.save()
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
