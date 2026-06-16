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
    -- Windows-style separators are accepted too.
    eq(util.dirname('a\\b\\c'), 'a\\b')
    eq(util.dirname('C:\\foo\\bar.snap'), 'C:\\foo')
end)

if util.isWindows then
    test.add('shellQuote (windows)', function()
        eq(util.shellQuote('simple'), '"simple"')
        eq(util.shellQuote('has spaces'), '"has spaces"')
        eq(util.shellQuote('a"b'), '"a""b"')
    end)
else
    test.add('shellQuote (posix)', function()
        eq(util.shellQuote('simple'), "'simple'")
        eq(util.shellQuote('has spaces'), "'has spaces'")
        eq(util.shellQuote("it's"), [['it'\''s']])
        eq(util.shellQuote('a"b'), [['a"b']])
        eq(util.shellQuote('$HOME `whoami`'), [['$HOME `whoami`']])
    end)
end

test.add('mkdirp creates nested directories', function()
    local sep = util.isWindows and '\\' or '/'
    -- On POSIX use awkward chars to prove our quoting handles them.
    -- On Windows cmd.exe forbids most of these in paths, so use a plain name.
    local leaf = util.isWindows and 'loon_test_dir' or "loon test '$dir`"
    local root = util.tmpdir() .. sep .. leaf
    local nested = root .. sep .. 'sub' .. sep .. 'leaf.snap'

    -- Pre-clean in case of stale state from a prior run.
    if util.isWindows then
        os.execute('rmdir /s /q ' .. util.shellQuote(root) .. ' 2>nul')
    else
        os.execute('rm -rf ' .. util.shellQuote(root))
    end

    local ok = util.mkdirp(util.dirname(nested))
    test.assert.truthy(ok, 'mkdirp succeeded')

    local probe = io.open(nested, 'w')
    test.assert.truthy(probe, 'parent directory exists and a file can be created in it')
    if probe then probe:close() end

    if util.isWindows then
        os.execute('rmdir /s /q ' .. util.shellQuote(root) .. ' 2>nul')
    else
        os.execute('rm -rf ' .. util.shellQuote(root))
    end
end)

test.run(arg)
