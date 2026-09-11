-- Display helpers shared by the pickers: filetype icons (via telescope's devicons
-- integration, so `disable_devicons` and missing nvim-web-devicons behave exactly
-- like the builtin pickers) and function-style displays that carry highlights.
local utils = require("telescope.utils")

local M = {}

M.STAR = "★ "
M.STAR_HL = "TelescopeResultsSpecialComment"

-- Icon for `path` plus its highlight group. Returns "", nil when icons are off.
function M.file_icon(path, opts)
  local icon, hl = utils.get_devicons(path, opts and opts.disable_devicons)
  if not icon or icon == "" then
    return "", nil
  end
  return icon .. " ", hl
end

-- Build a display string from segments { text, hl? } and return the pair
-- telescope expects from a display function: text plus byte-range highlights.
function M.segments(parts)
  local text, hls, pos = {}, {}, 0
  for _, p in ipairs(parts) do
    local s = p[1]
    if s ~= "" then
      if p[2] then
        hls[#hls + 1] = { { pos, pos + #s }, p[2] }
      end
      text[#text + 1] = s
      pos = pos + #s
    end
  end
  return table.concat(text), hls
end

-- Convenience: a `display` function that renders precomputed segments.
function M.display(parts)
  local text, hls = M.segments(parts)
  return function()
    return text, hls
  end
end

return M
