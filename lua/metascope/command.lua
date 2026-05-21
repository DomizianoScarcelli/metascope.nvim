local history_picker = require("metascope.history_picker")
local state = require("metascope.state")

local M = {}

function M.register()
  if state._command_registered then
    return
  end
  state._command_registered = true

  vim.api.nvim_create_user_command("Metascope", function(command_opts)
    local arg = command_opts.args
    if arg == "" or arg == "all" then
      history_picker.open()
    else
      history_picker.open({ types = arg })
    end
  end, {
    nargs = "?",
    desc = "Open Metascope search history",
    complete = function(arg_lead, _, _)
      local types = { "all" }
      for name, _ in pairs(state.type_config) do
        table.insert(types, name)
      end
      local matches = {}
      for _, t in ipairs(types) do
        if t:match("^" .. arg_lead) then
          table.insert(matches, t)
        end
      end
      return matches
    end,
  })
end

return M
