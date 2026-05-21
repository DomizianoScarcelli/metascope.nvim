local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
    error("This plugin requires nvim-telescope/telescope.nvim")
end

local metascope = require("metascope")

return telescope.register_extension({
    setup = function(ext_config, config) end,
    exports = {
        -- run :Telescope metascope history
        history = metascope.history_picker,
        metascope = metascope.history_picker,
    },
})
