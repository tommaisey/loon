-- Tests for the snapshot plugin's line-ending tolerance.
-- These run on every platform (we don't need Windows to exercise the
-- code path — we just write CRLF bytes to a temp file ourselves).
local test = require('loon')
local snap = require('loon.snap')
local util = require('loon.util')

local sep = util.isWindows and '\\' or '/'
local snapdir = util.tmpdir() .. sep .. 'loon-snap-eol-test'
assert(util.mkdirp(snapdir), 'could not create temp snapshot dir: ' .. snapdir)

-- Scope this file's snap.compare calls to our temp dir. Test customData
-- is captured at test.add time, so later snap.config calls in other test
-- files (terminal-output, junit-output) don't disturb these tests.
snap.config({dir = snapdir})

local function writeRaw(path, content)
    local f = assert(io.open(path, 'wb'), 'could not write ' .. path)
    f:write(content)
    f:close()
end

-----------------------------------------------------------------------------
test.suite.start('snap: line-ending tolerance')

-- Common payload used by the matching cases. CR-free in the actual we
-- compare against, so the only "difference" is line endings in the file.
local lfActual = 'line one\nline two\nline three\n'

test.add('CRLF snapshot file matches LF actual', function()
    writeRaw(snapdir .. sep .. 'crlf-match.snap', 'line one\r\nline two\r\nline three\r\n')
    snap.compare('crlf-match', lfActual)
end)

test.add('LF snapshot file matches LF actual', function()
    writeRaw(snapdir .. sep .. 'lf-match.snap', lfActual)
    snap.compare('lf-match', lfActual)
end)

test.add('mixed CRLF/LF snapshot still matches LF actual', function()
    writeRaw(snapdir .. sep .. 'mixed-match.snap', 'line one\r\nline two\nline three\r\n')
    snap.compare('mixed-match', lfActual)
end)

test.run(arg)
