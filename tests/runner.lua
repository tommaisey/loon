local test = require('loon')
local util = require('loon.util')
local eq = test.assert.equals

-----------------------------------------------------------------
test.suite.start('runner')

test.add('grouped restores export.run when a loaded file errors', function()
    -- Use a fresh loon instance so we don't disturb the outer runner.
    local loon = assert(loadfile('loon/loon.lua'))()
    local originalRun = loon.run

    -- Drop a Lua file in TMPDIR that errors on load. Put its directory
    -- onto package.path so `require`/`searchpath` can find it.
    local tmpdir = util.tmpdir()
    local sep = util.isWindows and '\\' or '/'
    local modname = 'loon_grouped_error_probe'
    local path = tmpdir .. sep .. modname .. '.lua'
    local f = assert(io.open(path, 'w'))
    f:write('error("intentional load failure")')
    f:close()

    local oldPath = package.path
    package.path = tmpdir .. sep .. '?.lua;' .. package.path
    -- Lua 5.1 caches require() results, including failures; clear it.
    if package.loaded then package.loaded[modname] = nil end

    local ok, err = pcall(loon.grouped, modname)

    package.path = oldPath
    os.remove(path)
    if package.loaded then package.loaded[modname] = nil end

    test.assert.falsey(ok, 'grouped propagated the load error')
    test.assert.string.contains(tostring(err), 'intentional load failure')
    eq(loon.run, originalRun,
        'export.run is restored after a failed grouped() call')
end)

test.run(arg)
