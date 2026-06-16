local util = require('loon.util')
local test = require('loon')
local eq = test.assert.equals

-----------------------------------------------------------------
test.suite.start('util')

test.add('dirname', function()
    eq(util.dirname('a/b/c'), 'a/b')
    eq(util.dirname('a/b/'), 'a/b')
    eq(util.dirname('a'), '.')
    eq(util.dirname(''), '.')
    eq(util.dirname('/etc/passwd'), '/etc')
    eq(util.dirname('weird name/file.snap'), 'weird name')
end)

test.add('shellQuote', function()
    eq(util.shellQuote('simple'), "'simple'")
    eq(util.shellQuote('has spaces'), "'has spaces'")
    eq(util.shellQuote("it's"), [['it'\''s']])
    eq(util.shellQuote('a"b'), [['a"b']])
    eq(util.shellQuote('$HOME `whoami`'), [['$HOME `whoami`']])
end)

test.add('mkdir -p round-trip through shellQuote handles awkward paths', function()
    -- Create a parent dir with a name containing characters that break the
    -- old Lua-%q quoting: spaces, single quotes, dollar signs, backticks.
    local base = os.getenv('TMPDIR') or '/tmp'
    base = base:gsub('/$', '')
    local awkward = base .. "/loon test '$dir`"
    local nested = awkward .. '/sub/leaf.snap'

    -- Pre-clean in case of stale state from a prior run.
    os.execute('rm -rf ' .. util.shellQuote(awkward))

    local rc = os.execute('mkdir -p ' .. util.shellQuote(util.dirname(nested)))
    test.assert.truthy(rc, 'mkdir -p succeeded')

    local probe = io.open(nested, 'w')
    test.assert.truthy(probe, 'parent directory exists and a file can be created in it')
    if probe then probe:close() end

    os.execute('rm -rf ' .. util.shellQuote(awkward))
end)

test.run(arg)
