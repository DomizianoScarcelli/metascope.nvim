local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")

local detect = require("metascope.detect")
local history = require("metascope.history")
local state = require("metascope.state")

local M = {}

function M.open_history_from_picker(search_type, prompt_bufnr)
  search_type = search_type or detect.search_type(prompt_bufnr)
  local filtered = history.filter_by_type(search_type)

  if #filtered == 0 then
    vim.notify("Metascope: no history for '" .. search_type .. "' yet", vim.log.levels.INFO)
    return
  end

  local current_prompt = actions_state.get_current_line() or ""
  actions.close(prompt_bufnr)
  -- Hand off on the next tick (no arbitrary delay) so the source picker has torn down.
  vim.schedule(function()
    require("metascope.history_picker").open({
      types = search_type,
      default_text = current_prompt,
    })
  end)
end

-- Pull the concrete destination (file path + position) out of the selected
-- Telescope entry so history can jump straight back to it later. Works across
-- find_files (path), live_grep (filename/lnum/col) and buffers (bufnr).
local function extract_target(entry)
  if not entry then
    return nil
  end
  local path = entry.path or entry.filename
  if (not path or path == "") and entry.bufnr and vim.api.nvim_buf_is_valid(entry.bufnr) then
    path = vim.api.nvim_buf_get_name(entry.bufnr)
  end
  if not path or path == "" then
    return nil
  end
  return {
    path = vim.fn.fnamemodify(path, ":p"),
    lnum = entry.lnum,
    col = entry.col,
  }
end

function M.attach_save_prompt(search_type)
  return function(prompt_bufnr, map)
    local picker = actions_state.get_current_picker(prompt_bufnr)
    if picker and search_type then
      picker._metascope_type = search_type
    end

    local function current_type()
      return search_type or detect.search_type(prompt_bufnr)
    end

    local function save_prompt_and_select()
      local t = current_type()
      local prompt = actions_state.get_current_line()
      local target = extract_target(actions_state.get_selected_entry())
      -- Record if there's a query to recall OR a concrete destination to return to.
      if (prompt and prompt ~= "") or target then
        history.push(prompt or "", t, target)
      end
      actions.select_default(prompt_bufnr)
    end

    map("i", "<CR>", save_prompt_and_select)
    map("n", "<CR>", save_prompt_and_select)

    if state.picker_history_keymap then
      local modes = state.picker_history_keymap_mode
      if type(modes) == "string" then
        modes = { modes }
      end
      for _, mode in ipairs(modes) do
        map(mode, state.picker_history_keymap, function()
          M.open_history_from_picker(current_type(), prompt_bufnr)
        end)
      end
    end

    return true
  end
end

return M
