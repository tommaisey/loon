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
local loon = assert(loadfile('loon/init.lua'))() -- copy that runs tests to generate snapshots
local eq = loon.assert.equals

snap.config(arg, {dir = "tests/snapshots/junit-output"})

local junit = {output = 'junit', times = false}

-- Since the tests may be run from this file directly, or indirectly
-- via 'all.lua', we normalize the file path in error traces so that
-- it is the same in both contexts, and the tests will pass.
local function normalizeFilePath(msg)
    return msg
        :gsub('junit%-output%.lua:%d+: in main chunk', '[[path normalized for test]]')
        :gsub('all%.lua:%d+: in main chunk', '[[path normalized for test]]')
end

-----------------------------------------------------------------------------
test.suite.start('junit output')

test.add('basics', function()
    snap.output('one passing - no message', function()
        loon.add('jabberwock', function()
            eq(42, 42)
        end)

        loon.run(junit)
    end)

    snap.output('one passing - with message', function()
        loon.add('jabberwock', function()
            eq(42, 42, 'here is the message')
        end)

        loon.run(junit)
    end)

    snap.output('one failing - no message', function()
        loon.add('jabberwock', function()
            eq(42, 99)
        end)

        loon.run(junit)
    end)

    snap.output('one failing - with message', function()
        loon.add('jabberwock', function()
            eq(42, 99, 'here is the message')
        end)

        loon.run(junit)
    end)

    snap.output('one errored', function()
        loon.add('jabberwock', function()
            error('I did a boo-boo')
        end)

        loon.run(junit)
    end, normalizeFilePath)

    snap.output('one failing test with one assertion failing among passes', function()
        loon.add('jabberwock', function()
            eq(1, 1)
            eq(2, 2)
            eq(42, 99, 'here is the message')
            eq(3, 3)
            eq(4, 4)
        end)

        loon.run(junit)
    end)

    snap.output('two passing tests', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('brillig', function()
            eq(2, 2)
        end)

        loon.run(junit)
    end)

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
    end)
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
    end)

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
    end)

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
    end)

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
    end)

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
    end)
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
    end)
end)

test.suite.stop('junit output')
test.run()