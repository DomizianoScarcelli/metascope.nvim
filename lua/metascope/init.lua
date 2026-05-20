local builtin = require('telescope.builtin')
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local actions_set = require("telescope.actions.set")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")

local M = {}

M.defaults = {
    max_history = 10000,
    picker_history_keymap = "J",
    picker_history_keymap_mode = "n",
}

-- Plugin State
M.history_file = vim.fn.stdpath("data") .. "/telescope_metascope_history.json"
M.max_history = M.defaults.max_history
M.telescope_history = {}
M.type_config = {}
---@type string|false Key in Telescope picker to open filtered history; false disables.
M.picker_history_keymap = M.defaults.picker_history_keymap
---@type string|string[] Vim mode(s) for picker_history_keymap (e.g. "n", "i", or { "n", "i" }).
M.picker_history_keymap_mode = M.defaults.picker_history_keymap_mode

-- ==========================================
-- SETUP & INITIALIZATION
-- ==========================================
function M.setup(opts)
    opts = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
    M.max_history = opts.max_history

    -- Default configuration
    M.type_config = vim.tbl_deep_extend("force", {
        grep = {
            icon = "󰊄 ",
            label = "Grep",
            builtin = "live_grep",
            opts = { vimgrep_arguments = { 'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case' } }
        },
        files = {
            icon = "󰈔 ",
            label = "File",
            builtin = "find_files",
            opts = { hidden = true }
        },
        buffers = {
            icon = "󰈙 ",
            label = "Buff",
            builtin = "buffers",
            opts = {}
        },
        default = {
            icon = " ",
            label = "Misc",
            builtin = "find_files",
            opts = {}
        }
    }, opts.type_config or {})

    M.picker_history_keymap = opts.picker_history_keymap
    M.picker_history_keymap_mode = opts.picker_history_keymap_mode

    M.build_detect_patterns()
    M.load_history()
end

function M.load_history()
    if vim.fn.filereadable(M.history_file) == 1 then
        local data = vim.fn.readfile(M.history_file)
        if data and data[1] then
            local ok, decoded = pcall(vim.fn.json_decode, data[1])
            if ok and type(decoded) == "table" then
                M.telescope_history = decoded
            end
        end
    end
end

function M.save_history()
    while #M.telescope_history > M.max_history do
        table.remove(M.telescope_history)
    end
    local ok, encoded = pcall(vim.fn.json_encode, M.telescope_history)
    if ok then
        vim.fn.writefile({ encoded }, M.history_file)
    end
end

-- ==========================================
-- CORE API
-- ==========================================
function M.build_detect_patterns()
    M._detect_patterns = {}
    for type_name, config in pairs(M.type_config) do
        if type_name ~= "default" then
            local patterns = { type_name }
            if config.label and config.label ~= "" then
                table.insert(patterns, config.label:lower():gsub("%s+", " "):match("^%s*(.-)%s*$"))
            end
            if config.builtin then
                table.insert(patterns, config.builtin:lower())
                table.insert(patterns, config.builtin:gsub("_", " "):lower())
            end
            M._detect_patterns[type_name] = patterns
        end
    end
    local extras = {
        files = { "find files", "git files", "oldfiles" },
        grep = { "live grep", "grep string", "grep" },
        buffers = { "buffers", "buffer" },
    }
    for type_name, more in pairs(extras) do
        if M._detect_patterns[type_name] then
            for _, pat in ipairs(more) do
                table.insert(M._detect_patterns[type_name], pat)
            end
        end
    end
end

--- Resolve metascope history type for the Telescope picker that owns prompt_bufnr.
function M.detect_search_type(prompt_bufnr)
    local picker = actions_state.get_current_picker(prompt_bufnr)
    if not picker then
        return "default"
    end

    if picker._metascope_type then
        return picker._metascope_type
    end

    if picker._opts and picker._opts.metascope_type then
        return picker._opts.metascope_type
    end

    local title = (picker.prompt_title or ""):lower()
    if title == "" then
        return "default"
    end

    if not M._detect_patterns then
        M.build_detect_patterns()
    end

    local best_type, best_len = nil, 0
    for type_name, patterns in pairs(M._detect_patterns) do
        for _, pattern in ipairs(patterns) do
            if pattern ~= "" and title:find(pattern, 1, true) then
                local len = #pattern
                if len > best_len then
                    best_len = len
                    best_type = type_name
                end
            end
        end
    end

    return best_type or "default"
end

function M.enrich_opts(search_type, opts)
    opts = vim.deepcopy(opts or {})
    opts.metascope_type = search_type
    if opts.default_text == nil then
        opts.default_text = M.get_last_search(search_type)
    end

    local user_attach = opts.attach_mappings
    opts.attach_mappings = function(prompt_bufnr, map)
        local picker = actions_state.get_current_picker(prompt_bufnr)
        if picker then
            picker._metascope_type = search_type
        end
        if user_attach then
            local ok = user_attach(prompt_bufnr, map)
            if ok == false then
                return false
            end
        end
        return M.make_attach_save_prompt(search_type)(prompt_bufnr, map)
    end
    return opts
end

function M.find_files(opts)
    builtin.find_files(M.enrich_opts("files", opts))
end

function M.live_grep(opts)
    builtin.live_grep(M.enrich_opts("grep", opts))
end

function M.buffers(opts)
    builtin.buffers(M.enrich_opts("buffers", opts))
end

function M.get_last_search(search_type)
    for _, entry in ipairs(M.telescope_history) do
        if entry.type == search_type then return entry.prompt end
    end
    return ""
end

function M.open_history_from_picker(search_type, prompt_bufnr)
    search_type = search_type or M.detect_search_type(prompt_bufnr)
    local filtered = {}
    for _, entry in ipairs(M.telescope_history) do
        if entry.type == search_type then
            table.insert(filtered, entry)
        end
    end

    if #filtered == 0 then
        print("No search history found for " .. search_type .. "!")
        return
    end

    local current_prompt = actions_state.get_current_line() or ""
    actions.close(prompt_bufnr)
    vim.defer_fn(function()
        M.history_picker({
            types = search_type,
            default_text = current_prompt,
        })
    end, 50)
end

function M.make_attach_save_prompt(search_type)
    return function(prompt_bufnr, map)
        local picker = actions_state.get_current_picker(prompt_bufnr)
        if picker and search_type then
            picker._metascope_type = search_type
        end

        local function current_type()
            return search_type or M.detect_search_type(prompt_bufnr)
        end

        local function save_prompt_and_select()
            local t = current_type()
            local prompt = actions_state.get_current_line()
            if prompt and prompt ~= "" then
                -- Deduplicate
                for i, entry in ipairs(M.telescope_history) do
                    if entry.prompt == prompt and entry.type == t then
                        table.remove(M.telescope_history, i)
                        break
                    end
                end
                -- Insert at the top
                table.insert(M.telescope_history, 1, {
                    prompt = prompt,
                    type = t,
                    timestamp = os.date("%m/%d %H:%M")
                })
                M.save_history()
            end
            actions.select_default(prompt_bufnr)
        end

        local function map_history_key()
            if not M.picker_history_keymap then
                return
            end
            local modes = M.picker_history_keymap_mode
            if type(modes) == "string" then
                modes = { modes }
            end
            for _, mode in ipairs(modes) do
                map(mode, M.picker_history_keymap, function()
                    M.open_history_from_picker(current_type(), prompt_bufnr)
                end)
            end
        end

        map("i", "<CR>", save_prompt_and_select)
        map("n", "<CR>", save_prompt_and_select)
        map_history_key()
        return true
    end
end

-- ==========================================
-- PREVIEWER & UI
-- ==========================================
local function get_preview_command(entry_value)
    if not entry_value.prompt or entry_value.prompt == "" then return { 'echo', 'Empty prompt' } end

    if entry_value.type == "grep" then
        local config = M.type_config.grep
        local cmd = vim.deepcopy(config.opts.vimgrep_arguments)
        for i, v in ipairs(cmd) do
            if v == "--color=never" then cmd[i] = "--color=always" end
        end
        table.insert(cmd, entry_value.prompt)
        return cmd
    elseif entry_value.type == "files" then
        if vim.fn.executable("fd") == 1 then
            return { 'fd', '--type', 'f', '--hidden', '--color=always', entry_value.prompt }
        else
            return { 'rg', '--files', '--hidden', '--color=always', '-g', '*' .. entry_value.prompt .. '*' }
        end
    end
    return { 'echo', 'Preview not configured for type: ' .. entry_value.type }
end

local history_previewer = previewers.new_termopen_previewer({
    get_command = function(entry, _) return get_preview_command(entry.value) end,
    title = "Live Results Preview"
})

function M.history_picker(opts)
    opts = opts or {}
    local filter_types = opts.types

    local results = {}
    if not filter_types then
        results = M.telescope_history
    else
        for _, entry in ipairs(M.telescope_history) do
            if type(filter_types) == "string" and entry.type == filter_types then
                table.insert(results, entry)
            elseif type(filter_types) == "table" and vim.tbl_contains(filter_types, entry.type) then
                table.insert(results, entry)
            end
        end
    end

    if #results == 0 then
        print("No search history found!")
        return
    end

    pickers.new(opts, {
        prompt_title = "Telescope History",
        layout_strategy = "horizontal",
        layout_config = {
            horizontal = {
                mirror = false,
                preview_width = 0.55,
            }
        },
        previewer = history_previewer,
        finder = finders.new_table({
            results = results,
            entry_maker = function(entry)
                local config = M.type_config[entry.type] or M.type_config.default
                local time_str = entry.timestamp and ("[" .. entry.timestamp .. "] ") or ""
                local display_str = string.format("%s%s[%s] %s", time_str, config.icon, config.label, entry.prompt)

                return { value = entry, display = display_str, ordinal = display_str }
            end
        }),
        sorter = sorters.get_generic_fuzzy_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions_set.select:replace(function(_, _)
                local selection = actions_state.get_selected_entry()
                actions.close(prompt_bufnr)

                if selection then
                    vim.defer_fn(function()
                        local entry = selection.value
                        local config = M.type_config[entry.type] or M.type_config.default
                        local builtin_fn = require('telescope.builtin')[config.builtin]

                        if builtin_fn then
                            local resume_opts = M.enrich_opts(entry.type, vim.deepcopy(config.opts))
                            resume_opts.prompt_title = config.label .. " (Resumed)"
                            resume_opts.default_text = entry.prompt
                            builtin_fn(resume_opts)
                        end
                    end, 50)
                end
            end)
            return true
        end,
    }):find()
end

M.setup({})

return M
