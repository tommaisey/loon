-----------------------------------------------------------------------------
-- We test our own library with the loon snapshot test library.
-- This means that we can't really test the snapshot runner itself,
-- but hey-ho, if you really want to verify it's working, you can
-- look at the snapshot files themselves, or even move the snapshot
-- directory, re-run the tests interactively, and check that the results
-- come out the same again.
--
-- NOTE! Unfortunately since the loon tests print line-numbers, if you
-- add a test anywhere except the top, you will have to re-approve tests
-- that contain line-numbers since they will have moved.
local snap = require('loon.snap')
local test = require('loon') -- copy that runs these tests
local loon = assert(loadfile('loon/loon.lua'))() -- copy that runs tests to generate snapshots
local eq = loon.assert.equals
local junit = {output = 'junit', times = false} -- config for junit output

snap.config(arg, {dir = "tests/snapshots/junit-output"})

-- This prevents line numbers and/or irrelevant stack information from
-- causing our tests to fail just because the line number or method of
-- invocation was different.
local normalizeStack = snap.normalizeStack('junit-output.lua', 'all.lua')

-----------------------------------------------------------------------------
test.suite.start('junit output')

test.add('basics', function()
    snap.output('one passing - no message', function()
        loon.add('jabberwock', function()
            eq(42, 42)
        end)

        loon.run(junit)
    end, normalizeStack)

    snap.output('one passing - with message', function()
        loon.add('jabberwock', function()
            eq(42, 42, 'here is the message')
        end)

        loon.run(junit)
    end, normalizeStack)

    snap.output('one failing - no message', function()
        loon.add('jabberwock', function()
            eq(42, 99)
        end)

        loon.run(junit)
    end, normalizeStack)

    snap.output('one failing - with message', function()
        loon.add('jabberwock', function()
            eq(42, 99, 'here is the message')
        end)

        loon.run(junit)
    end, normalizeStack)

    snap.output('one errored', function()
        loon.add('jabberwock', function()
            error('I did a boo-boo')
        end)

        loon.run(junit)
    end, normalizeStack)

    snap.output('one failing test with one assertion failing among passes', function()
        loon.add('jabberwock', function()
            eq(1, 1)
            eq(2, 2)
            eq(42, 99, 'here is the message')
            eq(3, 3)
            eq(4, 4)
        end)

        loon.run(junit)
    end, normalizeStack)

    snap.output('two passing tests', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('brillig', function()
            eq(2, 2)
        end)

        loon.run(junit)
    end, normalizeStack)

    snap.output('one failing test among passes', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('brillig', function()
            eq(2, 2)
            eq(2, 2)
        end)
        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.add('mimsy', function()
            eq(4, 4)
        end)

        loon.run(junit)
    end, normalizeStack)
end)

-----------------------------------------------------------------------------
test.add('test suites', function()
    snap.output('only top-level suites', function()
        loon.suite.start('suite 1')
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('brillig', function()
            eq(2, 2)
            eq(2, 2)
        end)
        loon.suite.stop('suite 1')

        loon.suite.start('suite 2')
        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.add('mimsy', function()
            eq(4, 4)
        end)
        loon.suite.stop('suite 2')
        loon.run(junit)
    end, normalizeStack)

    snap.output('nested suites', function()
        loon.suite.start('suite 1')
        loon.suite.start('suite nested 1')
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.suite.stop('suite nested 1')
        loon.add('brillig', function()
            eq(2, 2)
            eq(2, 2)
        end)
        loon.suite.stop('suite 1')

        loon.suite.start('suite 2')
        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.suite.start('suite nested 2')
        loon.add('mimsy', function()
            eq(4, 4)
        end)
        loon.suite.start('suite nested 2')
        loon.suite.stop('suite 2')
        loon.run(junit)
    end, normalizeStack)

    snap.output('mixed default and suites (1)', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.suite.start('suite 1')
        loon.add('brillig', function()
            eq(2, 2)
            eq(2, 2)
        end)
        loon.suite.stop('suite 1')

        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.suite.start('suite 2')
        loon.add('mimsy', function()
            eq(4, 4)
        end)
        loon.suite.stop('suite 2')
        loon.run(junit)
    end, normalizeStack)

    snap.output('mixed default and suites (2)', function()
        loon.suite.start('suite 1')
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.suite.stop('suite 1')
        loon.add('brillig', function()
            eq(2, 2)
            eq(2, 2)
        end)

        loon.suite.start('suite 2')
        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.suite.stop('suite 2')
        loon.add('mimsy', function()
            eq(4, 4)
        end)
        loon.run(junit)
    end, normalizeStack)

    snap.output('suite.add', function()
        loon.suite.add('suite 1', function()
            loon.add('jabberwock', function()
                eq(1, 1)
            end)
            loon.add('brillig', function()
                eq(2, 2)
                eq(2, 2)
            end)
        end)

        loon.suite.add('suite 2', function()
            loon.add('slithy', function()
                eq(3, 5)
            end)
            loon.suite.add('suite 3', function()
                loon.add('mimsy', function()
                    eq(4, 4)
                end)
            end)
        end)
        loon.run(junit)
    end, normalizeStack)
end)
-----------------------------------------------------------------------------
test.add('table output', function()
    snap.output('table equality', function()
        loon.add('flat', function()
            eq({a = 1, b = 2}, {a = 1, b = 3})
            eq({a = 1, b = 2}, {a = 1, c = 2})
            eq({1, 2, 3, 4}, {1, 2, 4, 5})
        end)
        loon.add('string', function()
            eq({a = 1, b = 'hi'}, {a = 1, b = 'byes'})
        end)
        loon.add('nested', function()
            eq({a = 1, b = {c = 2, d = {e = 3}, f = 'hi'}},
                {a = 1, b = {c = 2, d = {e = 7}, f = 'hi'}})
        end)

        loon.run(junit)
    end, normalizeStack)
end)

test.run(arg)
