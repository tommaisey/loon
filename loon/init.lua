-----------------------------------------------------------------------------
-- A super-lighweight testing library.
local export = {
    assert = {},
    suite = {}
}

-----------------------------------------------------------------------------
-- We use the serpent pretty-printing library for printing tables.
local serpent = require('loon.serpent')
local colored = require('loon.color')

-----------------------------------------------------------------------------
-- Cache some globals for speed.
local fmt = string.format
local type = type
local tostring = tostring
local insert = table.insert
local remove = table.remove
local iowrite = io.write

-----------------------------------------------------------------------------
-- This table of functions is used to colorize text.
-- If it's reassigned to 'uncolored', output will be uncolored.
-- This is done by individual 'run' functions as needed below.
local color = colored.yes

-----------------------------------------------------------------------------
-- Compose and write a formatted string to the default IO output file.
local function writef(fstring, ...)
    iowrite(fmt(fstring, ...), '\n')
end
local function newline()
    iowrite('\n')
end

local function stringify(x)
    if type(x) == 'table' then
        return serpent.block(x, {comment = false})
    end

    return tostring(x)
end

-- Always indent by 2 spaces, don't indent initial line
local function indent(text)
    return text:gsub('\n', '\n  ')
end

-----------------------------------------------------------------------------
-- Internal helper functions.

local function clone(tbl)
    local cloned = {}
    for k, v in pairs(tbl) do
        cloned[k] = v
    end
    return cloned
end

local function deepEquals(a, b)
    if type(a) == 'table' and type(b) == 'table' then
        for ka, va in pairs(a) do
            if not deepEquals(va, b[ka]) then
                return false
            end
        end
        for kb, vb in pairs(a) do
            if not deepEquals(vb, a[kb]) then
                return false
            end
        end

        return true
    end

    return a == b
end

local function failMsg(stackLevel, got, expected, text)
    local message = text and fmt("%s\n", color.msg(text)) or ''

    local info = debug.getinfo(stackLevel + 1, "S")
    local lineinfo = debug.getinfo(stackLevel + 1, "l")
    local location = fmt('%s:%s: ', color.file(info.short_src), color.line(lineinfo.currentline))

    local comparison
    expected = color.value(stringify(expected))
    got = color.fail(stringify(got))

    if expected:find('\n') or got:find('\n') then
        comparison = fmt('\nexpected: %s, got: %s', expected, got)
    elseif #expected + #got < 48 then
        comparison = fmt('expected: %s, got: %s', expected, got)
    else
        comparison = fmt('expected: \n%s.\ngot: \n%s', expected, got)
    end

    return message .. location .. comparison
end

local function interpretConfig(config)
    if config == nil then
        config = {}
    end

    if type(config[-1]) == 'string' and config[-1]:find('[Ll]ua') then
        -- TODO: it's a Lua 'arg' table, interpret it.
        config = {}
    end

    config.uncolored = config.uncolored or os.getenv('NO_COLOR')
    return config
end

--------------------------------------------------------------------------------------
-- The stateful part of the library, so be careful!
-- `tests` is the array of tests registered by user code so far.
-- `asserts` is the tally of assertions that have run in a currently running test.
local tests = {}
local asserts = {successes = 0, failed = {}}
local suiteDefault = {}
local suiteNow = suiteDefault
local suitePathStack = {}
local suiteStack = {suiteNow}

--------------------------------------------------------------------------------------
-- Add a test to be run. This test should contain at least one
-- assertion from Loon's assert sub-modules. After adding
-- some tests, you must call `run()` to run the tests.
function export.add(testName, testFunction)
    insert(tests, {testName, testFunction, suiteNow})
end

-- Begin a suite of tests. After this you should add some tests,
-- and then call `suite.stop()` to return to the parent/outer suite (if any)
function export.suite.start(name)
    insert(suitePathStack, name)
    suiteNow = clone(suitePathStack)
    insert(suiteStack, suiteNow)
end

-- End a suite of tests. You will now be in the parent/outer suite (if any).
-- Although this need not take any arguments, you can supply the same name
-- you used for the corresponding call to `suite.start()` for readability
-- reasons if you like.
function export.suite.stop(_name)
    assert(#suitePathStack > 0 and #suiteStack > 0, "Your suite.start/stop calls are unmatched!")
    remove(suitePathStack)
    remove(suiteStack)
    suiteNow = suiteStack[#suiteStack]
end

-- If you prefer not to call `suite.start()` & `suite.stop()` manually,
-- you can use this to run a series of tests inside a named suite.
function export.suite.with(name, functionContainingTests)
    export.suite.start(name)
    functionContainingTests()
    export.suite.stop()
end

-- Run a file of tests as a suite.
-- This allows you to run a collection of files,
-- each in their own suite.
function export.suite.file(requirePath)
    export.suite.start(requirePath)
    require(requirePath)
    export.suite.stop()
end

-- Since this module is stateful, you may occasionally need to
-- reset it, if you want to do multiple independent test runs.
-- This deletes all the tests that have been added up to this
-- point, and clears the current suite scope.
function export.clear()
    tests = {}
    asserts = {successes = 0, failed = {}}
    suiteNow = suiteDefault
    suitePathStack = {}
    suiteStack = {suiteNow}
end

--------------------------------------------------------------------------------------
function export.assert.equals(got, expected, text)
    if deepEquals(got, expected) then
        asserts.successes = asserts.successes + 1
    else
        insert(asserts.failed, failMsg(2, got, expected, text))
    end
end

export.assert.eq = export.assert.equals -- alias

--------------------------------------------------------------------------------------
-- Runs the tests, outputting the results in one of several ways,
-- depending on the configuration table.
function export.run(config)
    local outputs = {
        terminal = export.runTerminal,
        junit = export.runJunit
    }

    config = interpretConfig(config)
    return outputs[config.output or 'terminal'](config)
end

-- Runs the tests, outputting the results in a friendly terminal format.
function export.runTerminal(config)
    config = config or {}
    color = config.uncolored and colored.no or colored.yes
    local terse = config.terse

    -- Print newlines after test failure, but not after the last test.
    local newlineNext = false
    local function newlineIfNeeded()
        newlineNext = newlineNext and newline()
    end

    -- Write a breadcrumb title showing the suite we're in.
    local function writeSuiteBegin(suitePath)
        newlineIfNeeded()

        if #suitePath == 0 then
            writef('%s', color.suite('default suite'))
        else
            local title = {}

            for _, suite in ipairs(suitePath) do
                insert(title, color.suite(suite))
            end

            writef(table.concat(title, " > "))
        end
    end

    local function writeTest(name, numSuccesses, numFails, failures, errorObj)
        newlineIfNeeded()

        if errorObj or numFails > 0 then
            local title = fmt('%s %s', color.fail('x'), name)

            if errorObj then
                writef(title)
                local errorMsg = assert(errorObj.msg)
                local file, line, rest = errorMsg:match('([^:]+):(%d+):(.*)')
                local intro = fmt('  (%s)', color.fail('ERROR'))

                if file and line and rest then
                    writef('%s %s:%s:%s', intro, color.file(file), color.line(line), indent(rest))
                else
                    writef('%s %s', intro, indent(errorMsg))
                end

                if errorObj.trace then
                    writef('    %s', indent(errorObj.trace))
                end
            else
                writef('%s [%s fail, %s pass]', title, color.fail(numFails), color.pass(numSuccesses))

                for n, failure in ipairs(failures) do
                    writef('  (%s) %s', color.fail(n), indent(failure))
                end
            end

            newlineNext = true
        elseif not terse then
            local summary = asserts.successes > 0
                and color.pass(asserts.successes) .. ' pass'
                or  color.warn('no assertions')
            writef('%s %s [%s]', color.pass('+'), name, summary)
        end
    end

    local function writeSummary(testPasses, testFails, assertPasses, assertFails)
        writef('--------------------------')

        if testFails > 0 then
            writef(
                '%s: %s tests, %s assertions',
                color.pass('pass'),
                color.pass(testPasses),
                color.pass(assertPasses)
            )
            writef(
                '%s: %s tests, %s assertions',
                color.fail('fail'),
                color.fail(testFails),
                color.fail(assertFails)
            )
        else
            writef('%s: %s', color.pass('all tests pass'), color.pass(testPasses))
            writef('%s %s', 'assertions:', assertPasses)
        end
    end

    return export.runWith(writeSuiteBegin, writeTest, nil, writeSummary)
end

-- Runs the tests, outputting the results in JUNIT's standard XMl format.
function export.runJunit()
    color = colored.no
    writef('<?xml version="1.0" encoding="UTF-8"?>\n')

    local suite
    local suites = {}
    local suiteOrder = {}
    local numSuccessAsserts = 0
    local numFailAsserts = 0
    local numErrorTests = 0

    -- Write a breadcrumb title showing the suite we're in.
    local function writeSuiteBegin(suitePath)
        suite = suites[suitePath]

        if suite == nil then
            suite = {}
            suites[suitePath] = suite
            insert(suiteOrder, suitePath)
        end
    end

    local function writeTest(name, numSuccesses, numFails, failures, errorObj)
        numSuccessAsserts = numSuccessAsserts + numSuccesses
        numFailAsserts = numFailAsserts + numFails
        local numAssertions = numSuccesses + numFails

        if errorObj or numFails > 0 then
            if errorObj then
                insert(suite, {name = name, errorObj = errorObj, assertions = numAssertions})
                numErrorTests = numErrorTests + 1
            else
                insert(suite, {name = name, failures = failures, assertions = numAssertions})
            end
        else
            insert(suite, {name = name, assertions = numAssertions})
        end
    end

    local function writeSuiteEnd(suitePath)
        suite = assert(suites[suitePath])
    end

    local startTime = os.clock()

    local function writeSummary(testPasses, testFails, assertPasses, assertFails)
        local endTime = os.clock()

        writef(
            '<testsuites tests="%d" failures="%d" errors="%d" assertions="%d" skipped="0" time="%g">',
            testPasses + testFails,
            testFails,
            numErrorTests,
            assertPasses + assertFails,
            endTime - startTime
        )

        -- Remove empty test suites from the results
        for i = #suiteOrder, 1, -1 do
            if #(suites[suiteOrder[i]]) == 0 then
                remove(suiteOrder, i)
            end
        end

        for _, testSuite in ipairs(suiteOrder) do
            local suiteName = #testSuite == 0 and "default" or table.concat(testSuite, " > ")

            writef('  <testsuite name="%s">', suiteName)
            writef('    <properties><property name="Lua Version" value="%s" /></properties>', _VERSION)

            for _, result in ipairs(suites[testSuite]) do
                local name, num = result.name, result.assertions

                if result.errorObj then
                    local msg, trace = result.errorObj.msg, result.errorObj.trace
                    writef('    <testcase name="%s" classname="%s" assertions="%d">', name, suiteName, num)
                    writef('      <error message="%s">', msg)
                    writef('        <![CDATA[%s]]>', trace)
                    writef('      </error>')
                    writef('    </testcase>')
                elseif result.failures then
                    writef('    <testcase name="%s" classname="%s" assertions="%d">', name, suiteName, num)

                    for _, failure in ipairs(result.failures) do
                        writef('      <failure message="%s"></failure>', failure)
                    end

                    writef('    </testcase>')
                else
                    writef('    <testcase name="%s" classname="%s" assertions="%d" />', name, suiteName, num)
                end
            end

            writef('  </testsuite>')
        end

        writef('</testsuites>')
    end

    return export.runWith(writeSuiteBegin, writeTest, writeSuiteEnd, writeSummary)
end

-- Runs each test, calling the writeTest() function for each.
-- Finally calls the writeSummary() function.
function export.runWith(writeSuiteBegin, writeTest, writeSuiteEnd, writeSummary)
    local function none() end
    writeSuiteBegin = writeSuiteBegin or none
    writeTest = writeTest or none
    writeSuiteEnd = writeSuiteEnd or none
    writeSummary = writeSummary or none

    local testPasses, testFails = 0, 0
    local assertPasses, assertFails = 0, 0

    local noSuite = {}
    local currentSuite = noSuite

    for _, info in ipairs(tests) do
        asserts.successes, asserts.failed = 0, {}
        local name, fn, suite = info[1], info[2], info[3]
        local noError, errorObj = xpcall(fn, function(errorMsg)
            return {msg = errorMsg, trace = debug.traceback(nil, 8)}
        end)

        if suite ~= currentSuite then
            if #suite <= #currentSuite and suite ~= suiteDefault then
                writeSuiteEnd(currentSuite)
            end

            writeSuiteBegin(suite)
            currentSuite = suite
        end

        local failures = asserts.failed
        local numFails = #failures
        local numSuccesses = asserts.successes
        assertFails = assertFails + numFails
        assertPasses = assertPasses + asserts.successes
        errorObj = not noError and errorObj or nil -- in case test fn returned something

        if errorObj or numFails > 0 then
            testFails = testFails + 1
        else
            testPasses = testPasses + 1
        end

        writeTest(name, numSuccesses, numFails, failures, errorObj)
    end

    writeSummary(testPasses, testFails, assertPasses, assertFails)
    return testFails
end

return export