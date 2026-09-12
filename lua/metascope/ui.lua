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

-- "just now", "5m ago", "3h ago", "2d ago", "3w ago" — from a unix time.
function M.relative_time(t, now)
  if not t then
    return ""
  end
  local d = math.max(0, (now or os.time()) - t)
  if d < 60 then
    return "just now"
  elseif d < 3600 then
    return math.floor(d / 60) .. "m ago"
  elseif d < 86400 then
    return math.floor(d / 3600) .. "h ago"
  elseif d < 7 * 86400 then
    return math.floor(d / 86400) .. "d ago"
  elseif d < 30 * 86400 then
    return math.floor(d / (7 * 86400)) .. "w ago"
  end
  return math.floor(d / (30 * 86400)) .. "mo ago"
end

-- Short human form of a key for prompt-title hints: "<C-h>" -> "^H", "J" -> "J".
function M.key_hint(lhs)
  if type(lhs) ~= "string" or lhs == "" then
    return nil
  end
  local ctrl = lhs:match("^<[Cc]%-(.)>$")
  if ctrl then
    return "^" .. ctrl:upper()
  end
  return lhs
end

-- "<title> · ^H history": tells people the history key exists without docs.
function M.title_with_hint(title, lhs)
  local hint = M.key_hint(lhs)
  if not hint then
    return title
  end
  return title .. " · " .. hint .. " history"
end

return M
