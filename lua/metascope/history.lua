local state = require("metascope.state")

local M = {}

function M.load()
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

function M.save()
  while #state.telescope_history > state.max_history do
    table.remove(state.telescope_history)
  end

  local ok, encoded = pcall(vim.fn.json_encode, state.telescope_history)
  if ok then
    vim.fn.writefile({ encoded }, state.history_file)
  end
end

function M.get_last(search_type)
  for _, entry in ipairs(state.telescope_history) do
    if entry.type == search_type then
      return entry.prompt
    end
  end
  return ""
end

function M.push(prompt, search_type)
  for i, entry in ipairs(state.telescope_history) do
    if entry.prompt == prompt and entry.type == search_type then
      table.remove(state.telescope_history, i)
      break
    end
  end

  table.insert(state.telescope_history, 1, {
    prompt = prompt,
    type = search_type,
    timestamp = os.date("%m/%d %H:%M"),
  })
  M.save()
end

function M.remove(prompt, search_type)
  for i, entry in ipairs(state.telescope_history) do
    if entry.prompt == prompt and entry.type == search_type then
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
