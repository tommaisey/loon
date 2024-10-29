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

snap.config(arg, {dir = "tests/snapshots/terminal-output"})

-- This prevents line numbers and/or irrelevant stack information from
-- causing our tests to fail just because the line number or method of
-- invocation was different.
local normalizeStack = snap.normalizeStack('terminal-output.lua', 'all.lua')

-----------------------------------------------------------------------------
test.suite.start('terminal output')

test.add('basics', function()
    snap.output('one passing - no message', function()
        loon.add('jabberwock', function()
            eq(42, 42)
        end)

        loon.run()
    end, normalizeStack)

    snap.output('one passing - with message', function()
        loon.add('jabberwock', function()
            eq(42, 42, 'here is the message')
        end)

        loon.run()
    end, normalizeStack)

    snap.output('one failing - no message', function()
        loon.add('jabberwock', function()
            eq(42, 99)
        end)

        loon.run()
    end, normalizeStack)

    snap.output('one failing - with message', function()
        loon.add('jabberwock', function()
            eq(42, 99, 'here is the message')
        end)

        loon.run()
    end, normalizeStack)

    snap.output('one errored', function()
        loon.add('jabberwock', function()
            error('I did a boo-boo')
        end)

        loon.run()
    end, normalizeStack)

    snap.output('one failing test with one assertion failing among passes', function()
        loon.add('jabberwock', function()
            eq(1, 1)
            eq(2, 2)
            eq(42, 99, 'here is the message')
            eq(3, 3)
            eq(4, 4)
        end)

        loon.run()
    end, normalizeStack)

    snap.output('two passing tests', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('brillig', function()
            eq(2, 2)
        end)

        loon.run()
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

        loon.run()
    end, normalizeStack)
end)

test.add('terse option', function()
    snap.output('terse - all pass', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('mimsy', function()
            eq(4, 4)
        end)

        loon.run({terse = true})
    end, normalizeStack)

    snap.output('terse - one failure', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.add('mimsy', function()
            eq(4, 4)
        end)

        loon.run({terse = true})
    end, normalizeStack)
end)

test.add('uncolored option', function()
    snap.output('uncolored - basic', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.add('mimsy', function()
            eq(4, 4)
        end)

        loon.run({uncolored = true})
    end, normalizeStack)
end)

-----------------------------------------------------------------------------
test.add('assertions', function()
    snap.output('assert.equals', function()
        loon.add('equals', function()
            loon.assert.eq(1, 1)
            loon.assert.equals(1, 1)
            loon.assert.eq(3, 5)
            loon.assert.equals(3, 5)
        end)

        loon.run()
    end, normalizeStack)

    snap.output('assert.near', function()
        loon.add('near', function()
            loon.assert.near(7, 7)
            loon.assert.nearly(7, 7)

            loon.assert.near(7, 7, 0.1)
            loon.assert.nearly(7, 7, 0.1)

            loon.assert.near(7, 7.05, 0.1)
            loon.assert.nearly(7, 7.05, 0.1)
            loon.assert.near(7, 6.95, 0.1)
            loon.assert.nearly(7, 6.95, 0.1)

            loon.assert.near(7.8, 8, 0.1)
            loon.assert.nearly(7.8, 8, 0.1)
            loon.assert.near(8.2, 8, 0.08)
            loon.assert.nearly(8.2, 8, 0.08)

            loon.assert.near(7, 8, 1.2)
            loon.assert.nearly(7, 8, 1.2)
            loon.assert.near(8, 8, 1.2)
            loon.assert.nearly(8, 7, 1.2)
        end)

        loon.run()
    end, normalizeStack)

    snap.output('assert.string.contains', function()
        loon.add('string.contains', function()
            loon.assert.string.contains('To err is human, but it feels divine', 'human')
            loon.assert.string.contains('To err is human, but it feels divine', '[Hh]uman')
            loon.assert.string.contains('To err is human, but it feels divine', 'godly')
        end)

        loon.run()
    end, normalizeStack)

    snap.output('assert.error.contains', function()
        loon.add('error.contains', function()
            loon.assert.error.contains('blammo', function()
                error('blammo')
            end)

            loon.assert.error.contains('blammo', function()
                error('and blammo was his namo')
            end)

            loon.assert.error.contains('[Bb]lammo', function()
                error('casing Blammo how I wish')
            end)

            loon.assert.error.contains('[Bb]lammo', function()
                error('anyone met my mate dammo?')
            end)
        end)

        loon.run()
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
        loon.run()
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
        loon.run()
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
        loon.run()
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
        loon.run()
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
                eq(3, 3)
            end)
            loon.suite.add('suite 3', function()
                loon.add('mimsy', function()
                    eq(4, 4)
                end)
            end)
        end)
        loon.run()
    end, normalizeStack)
end)
-----------------------------------------------------------------------------
test.add('table output', function()
    snap.output('table equality (colored)', function()
        loon.add('flat', function()
            eq({a = 1, b = 2}, {a = 1, b = 3})
        end)
        loon.run()
    end, normalizeStack)

    snap.output('table equality (uncolored, deeper)', function()
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

        loon.run({uncolored = true})
    end, normalizeStack)
end)

test.run(arg)
