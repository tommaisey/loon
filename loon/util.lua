local luaMajor, luaMinor = _VERSION:match('Lua (%d)%.(%d)')
local luav = (tonumber(luaMajor) * 10) + tonumber(luaMinor)

-- POSIX shell quoting: wrap in single quotes, escape embedded single quotes.
local function shellQuote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Returns the directory portion of a forward-slash path, or '.' if there is none.
local function dirname(path)
    return path:match('^(.*)/[^/]*$') or '.'
end

return {
    luaversion = luav,
    shellQuote = shellQuote,
    dirname = dirname,
}
