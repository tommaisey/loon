local luaMajor, luaMinor = _VERSION:match('Lua (%d)%.(%d)')
local luav = (tonumber(luaMajor) * 10) + tonumber(luaMinor)

return {
    luaversion = luav
}
