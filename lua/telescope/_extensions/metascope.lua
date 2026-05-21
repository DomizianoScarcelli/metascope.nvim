local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("metascope.nvim requires nvim-telescope/telescope.nvim")
end

return telescope.register_extension({
  exports = {
    history = require("metascope").history_picker,
    metascope = require("metascope").history_picker,
  },
})
