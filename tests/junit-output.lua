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
local loon = require('loon')
local snap = require('loon.snap')
local eq = loon.assert.equals
local tests = {}

local function run(test)
    local path = os.tmpname()
    local file = assert(io.open(path, 'w+'), "test runner couldn't open temporary file")

    io.output(file)
    local config = test()
    loon.run(config, {output = 'junit', times = false})
    loon.clear()

    io.output(io.stdout)
    file:close()
    file = io.open(path, 'r')
    local result = file:read('a')
    file:close()
    os.remove(path)
    return result
end

local function test(title, testFn)
    table.insert(tests, {title = title, test = testFn})
end

local function execute()
    for _, elem in ipairs(tests) do
        snap.test(elem.title, run(elem.test))
    end

    os.exit(snap.run(arg, {dir = "tests/snapshots"}))
end

-----------------------------------------------------------------------------
test('junit - one passing test with no message', function()
    loon.add('jabberwock', function()
        eq(42, 42)
    end)
end)

test('junit - one passing test with a message', function()
    loon.add('jabberwock', function()
        eq(42, 42, 'here is the message')
    end)
end)

test('junit - one failing test with no message', function()
    loon.add('jabberwock', function()
        eq(42, 99)
    end)
end)

test('junit - one failing test with a message', function()
    loon.add('jabberwock', function()
        eq(42, 99, 'here is the message')
    end)
end)

test('junit - one failing test with one assertion failing among passes', function()
    loon.add('jabberwock', function()
        eq(1, 1)
        eq(2, 2)
        eq(42, 99, 'here is the message')
        eq(3, 3)
        eq(4, 4)
    end)
end)

test('junit - two passing tests', function()
    loon.add('jabberwock', function()
        eq(1, 1)
    end)
    loon.add('brillig', function()
        eq(2, 2)
    end)
end)

test('junit - one failing test among passes', function()
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
end)

-----------------------------------------------------------------------------
test('junit - only top-level suites', function()
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
end)

test('junit - nested suites', function()
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
end)

test('junit - mixed default and suites (1)', function()
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
end)

test('junit - mixed default and suites (2)', function()
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
end)

test('junit - suite.with', function()
    loon.suite.with('suite 1', function()
        loon.add('jabberwock', function()
            eq(1, 1)
        end)
        loon.add('brillig', function()
            eq(2, 2)
            eq(2, 2)
        end)
    end)

    loon.suite.with('suite 2', function()
        loon.add('slithy', function()
            eq(3, 5)
        end)
        loon.suite.with('suite 3', function()
            loon.add('mimsy', function()
                eq(4, 4)
            end)
        end)
    end)
end)

-----------------------------------------------------------------------------
test('junit - table equality (colored)', function()
    loon.add('flat', function()
        eq({a = 1, b = 2}, {a = 1, b = 3})
    end)
end)

test('junit - table equality (uncolored, more comprehensive)', function()
    loon.add('flat', function()
        eq({a = 1, b = 2}, {a = 1, b = 3})
        eq({a = 1, b = 2}, {a = 1, c = 2})
        eq({1, 2, 3, 4}, {1, 2, 4, 5})
    end)
    loon.add('string', function()
        eq({a = 1, b = 'hi'}, {a = 1, b = 'byes'})
    end)
    loon.add('nested', function()
        eq(
            {a = 1, b = {c = 2, d = {e = 3}, f = 'hi'}},
            {a = 1, b = {c = 2, d = {e = 7}, f = 'hi'}}
        )
    end)

    return {uncolored = true}
end)

execute()
