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
    print("No search history found for " .. search_type .. "!")
    return
  end

  local current_prompt = actions_state.get_current_line() or ""
  actions.close(prompt_bufnr)
  vim.defer_fn(function()
    require("metascope.history_picker").open({
      types = search_type,
      default_text = current_prompt,
    })
  end, 50)
end

function M.cycle_history(prompt_bufnr, direction)
  local picker = actions_state.get_current_picker(prompt_bufnr)
  local search_type = detect.search_type(prompt_bufnr)
  local filtered = history.filter_by_type(search_type)

  if #filtered == 0 then
    return
  end

  if state.cycle_index == nil then
    state.cycle_index = direction == "next" and 1 or #filtered
  else
    state.cycle_index = state.cycle_index + (direction == "next" and 1 or -1)
  end

  if state.cycle_index > #filtered then
    state.cycle_index = 1
  end
  if state.cycle_index < 1 then
    state.cycle_index = #filtered
  end

  picker:set_prompt(filtered[state.cycle_index].prompt)
end

function M.attach_save_prompt(search_type)
  return function(prompt_bufnr, map)
    local picker = actions_state.get_current_picker(prompt_bufnr)
    if picker and search_type then
      picker._metascope_type = search_type
    end

    state.cycle_index = nil

    local function current_type()
      return search_type or detect.search_type(prompt_bufnr)
    end

    local function save_prompt_and_select()
      local t = current_type()
      local prompt = actions_state.get_current_line()
      if prompt and prompt ~= "" then
        history.push(prompt, t)
      end
      actions.select_default(prompt_bufnr)
    end

    map("i", "<CR>", save_prompt_and_select)
    map("n", "<CR>", save_prompt_and_select)
    map("i", "<Up>", function()
      M.cycle_history(prompt_bufnr, "prev")
    end)
    map("i", "<Down>", function()
      M.cycle_history(prompt_bufnr, "next")
    end)

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
