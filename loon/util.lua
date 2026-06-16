local luaMajor, luaMinor = _VERSION:match('Lua (%d)%.(%d)')
local luav = (tonumber(luaMajor) * 10) + tonumber(luaMinor)

-- `package.config`'s first line is the directory separator:
-- '/' on POSIX, '\' on Windows.
local isWindows = package.config:sub(1, 1) == '\\'

-- POSIX shell quoting: wrap in single quotes, escape embedded single quotes.
local function shellQuotePosix(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Windows cmd.exe quoting: wrap in double quotes, double any embedded
-- double quotes. Backslashes don't need escaping for cmd.exe itself, but
-- we still convert forward slashes to backslashes when used as path args
-- to commands like `mkdir`.
local function shellQuoteWin(s)
    return '"' .. s:gsub('"', '""') .. '"'
end

local shellQuote = isWindows and shellQuoteWin or shellQuotePosix

-- Returns the directory portion of a path, or '.' if there is none.
-- Accepts both '/' and '\\' as separators so it works on Windows paths too.
local function dirname(path)
    return path:match('^(.*)[/\\][^/\\]*$') or '.'
end

-- Returns a writable temporary directory, with no trailing separator.
-- Honors TMPDIR/TEMP/TMP, falling back to platform defaults.
local function tmpdir()
    local d = os.getenv('TMPDIR') or os.getenv('TEMP') or os.getenv('TMP')
        or (isWindows and 'C:\\Windows\\Temp' or '/tmp')
    return (d:gsub('[/\\]$', ''))
end

-- Recursively create a directory (like `mkdir -p`), cross-platform.
-- Returns truthy on success or if the directory already exists.
local function mkdirp(path)
    if isWindows then
        -- cmd.exe's `mkdir` creates intermediate directories implicitly,
        -- but it errors if the leaf already exists. Suppress that with `2>nul`
        -- and ignore the exit code: if the directory ends up present, we win.
        local winPath = path:gsub('/', '\\')
        os.execute('mkdir ' .. shellQuoteWin(winPath) .. ' 2>nul')
        -- Probe: can we open a file inside it? If the directory exists,
        -- io.open with 'a' (append) on a probe path succeeds.
        local probe = path .. '/.loon-mkdirp-probe'
        local f = io.open(probe, 'a')
        if f then f:close(); os.remove(probe); return true end
        return false
    else
        return os.execute('mkdir -p ' .. shellQuotePosix(path))
    end
end

return {
    luaversion = luav,
    isWindows = isWindows,
    shellQuote = shellQuote,
    dirname = dirname,
    tmpdir = tmpdir,
    mkdirp = mkdirp,
}
