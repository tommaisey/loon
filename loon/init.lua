-----------------------------------------------------------------------------
-- A super-lighweight testing library.
local export = {
    assert = {},
    suite = {},
    plugin = {}
}

-----------------------------------------------------------------------------
-- We use the serpent pretty-printing library for printing tables.
local serpent = require('loon.serpent')
local colored = require('loon.color')
local args = require('loon.args')

-----------------------------------------------------------------------------
local argsBase = {
    output = {'terminal', 'junit'},
    uncolored = {true, false},
    terse = {true, false},
    times = {true, false},
    help = {true, false}
}

local argsBaseDefaults = {
    uncolored = os.getenv('NO_COLOR'),
    times = true,
    help = false,
    output = 'terminal'
}

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
-- Internal helper functions.
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

local function normalizeRelativePath(str)
    return str:gsub('%./', '')
end

-- Always indent by 2 spaces, don't indent initial line
local function indent(text)
    return text:gsub('\n', '\n  ')
end

local function clone(tbl)
    local cloned = {}
    for k, v in pairs(tbl) do
        cloned[k] = v
    end
    return cloned
end

local function defaultFailMsg(srcLocation, _pluginConfig, ...)
    if select(..., '#') == 0 then
        return fmt('%s: assertion failed (no arguments)', srcLocation)
    end

    local arguments = {...}
    for i, a in ipairs(arguments) do arguments[i] = fmt('%q', a) end

    return fmt('%s: assertion failed with arguments: %s', srcLocation, table.concat(arguments, ', '))
end

local function equalsFailMsg(srcLocation, _pluginConfig, got, expected, text)
    local message = text and fmt("%s\n", color.msg(text)) or ''
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

    return message .. srcLocation .. comparison
end

local function deepEquals(a, b)
    if type(a) == 'table' and type(b) == 'table' then
        for ka, va in pairs(a) do
            if not deepEquals(va, b[ka]) then
                return false
            end
        end
        for kb, vb in pairs(b) do
            if not deepEquals(vb, a[kb]) then
                return false
            end
        end

        return true
    end

    return a == b
end

--------------------------------------------------------------------------------------
-- The stateful part of the library, so be careful!
-- `tests` is the array of tests registered by user code so far.
-- `asserts` is the tally of assertions that have run in a currently running test.
local tests = {}
local asserts = {successes = 0, failed = {}}
local suitePathStack = {}
local suiteDefault = {}
local suiteNow = suiteDefault
local suiteStack = {suiteNow}
local pluginSummaries = {}
local pluginSummariesOrdered = {}
local pluginConfig
local argsMerged = clone(argsBase)
local argsMergedDefaults = clone(argsBaseDefaults)

local function reset()
    tests = {}
    asserts = {successes = 0, failed = {}}
    suitePathStack = {}
    suiteNow = suiteDefault
    suiteStack = {suiteNow}
    pluginSummaries = {}
    pluginSummariesOrdered = {}
    pluginConfig = nil
    argsMerged = clone(argsBase)
    argsMergedDefaults = clone(argsBaseDefaults)
end

--------------------------------------------------------------------------------------
-- Runs each test, calling the writeTest() function for each.
-- Finally calls the writeSummary() function.
local function runWith(writeSuiteBegin, writeTest, writeSuiteEnd, writeSummary)
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
        local name, fn, suite, config = info[1], info[2], info[3], info[4]

        pluginConfig = config -- may be retrieved by plugins

        local noError, errorObj = xpcall(fn, function(errorMsg)
            local norm = normalizeRelativePath
            return {msg = norm(errorMsg), trace = norm(debug.traceback(nil, 8))}
        end)

        pluginConfig = nil

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

    for _, summary in ipairs(pluginSummariesOrdered) do
        local result = summary()

        if result ~= nil and result ~= 0 then
            return result
        end
    end

    return testFails
end

-- Runs the tests, outputting the results in a friendly terminal format.
local function runTerminal(config)
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

    return runWith(writeSuiteBegin, writeTest, nil, writeSummary)
end

-- Runs the tests, outputting the results in JUNIT's standard XMl format.
local function runJunit(config)
    color = colored.no
    local times = config.times
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
            '<testsuites tests="%d" failures="%d" errors="%d" assertions="%d" skipped="0"%s>',
            testPasses + testFails,
            testFails,
            numErrorTests,
            assertPasses + assertFails,
            times and fmt(' time="%g"', endTime - startTime) or ""
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
                        writef('      <failure message="%s"></failure>', failure:gsub('\n', '&#10;'))
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

    return runWith(writeSuiteBegin, writeTest, writeSuiteEnd, writeSummary)
end

--------------------------------------------------------------------------------------
-- The public part of the library.

-- Add a test to be run. This test should contain at least one
-- assertion from Loon's assert sub-modules. After adding
-- some tests, you must call `run()` to run the tests.
function export.add(testName, testFunction)
    insert(tests, {testName, testFunction, suiteNow, pluginConfig})
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
function export.suite.add(name, functionContainingTests)
    export.suite.start(name)
    functionContainingTests()
    export.suite.stop()
end

-- Collect all the tests in a series of test files.
-- The tests will not be run, even if the files contain
-- a call to `run()`, so you must call it yourself after
-- calling this. This allows you to run files individually
-- or in groups simply by loading a specific file or file
-- containing a call to `collect()`.
function export.grouped(...)
    local run = export.run
    export.run = function() end

    for _, requireStyleString in ipairs({...}) do
        local file = package.searchpath(requireStyleString, package.path)
        assert(loadfile(file))()
    end

    export.run = run
end

--------------------------------------------------------------------------------------
-- Allows a plugin to set a temporary configuration which is saved
-- alongside each test added thereafter. This can be retrieved when
-- the test runs using `getConfig()`, so that the plugin can adjust
-- behaviour according to the config that was set for that region
-- of code.
function export.plugin.config(arguments, defaults, customData)
    for k, v in pairs(arguments) do
        argsMerged[k] = v
    end
    for k, v in pairs(defaults) do
        argsMergedDefaults[k] = v
    end

    pluginConfig = customData
end

-- Get the custom data that was set at the time that the current
-- (running) test was defined by `plugin.config()`
function export.plugin.getCustomData()
    return pluginConfig
end

-- Allows plugins (such as the snapshot testing plugin) to register
-- one or more functions that will be executed after the test run.
-- Your function will receive no arguments, so its reliant on your
-- internal state. If your function returns non-nil, and the value
-- returned is not `0`, the test will exit before running any more
-- summaries.
--
-- You MAY want to print some extra data from your plugin in a summary function.
-- You MUST reset any internal plugin in a summary function.
function export.plugin.summary(name, func)
    -- We ignored duplicate summary functions, so that plugins can
    -- idempotently re-declare them. This allows users to use and
    -- configure a plugin multiple times without causing duplicates.
    if pluginSummaries[name] then
        return
    end

    pluginSummaries[name] = func
    insert(pluginSummariesOrdered, func)
end

--------------------------------------------------------------------------------------
-- Allows you to create an assertion function that hooks into the loon
-- test system. The returned function will have the same arguments as
-- `yourAssert` (which should return `true`/`false`) and can be used
-- as an assertion in tests. You may also supply a function that creates
-- string describing failure. This should take a string describing the
-- source location of the failed assertion, then a plugin config object
-- which will be anything set by `plugin.config()` (or `nil`), followed
-- by the same arguments supplied to `yourAssert`.
--
-- This is of course very useful for plugins, such as the snapshot plugin.
--
-- @usage
-- local function stringsEqualIgnoringCase(a, b)
--     return a:lower() == b:lower()
-- end
--
-- local function stringsNotEqualFailMsg(srcLocation, pluginConfig, a, b)
--     return string.format("%s: strings don't match: '%s' vs. '%s'", srcLocation, a, b)
-- end
--
-- -- Create an assertion function you can use inside tests:
-- local assertEqCaseInsensitive = loon.assert.create(stringsEqualIgnoringCase, caseInsensitiveFailMsg)
function export.assert.create(yourAssert, failMsgFn)
    failMsgFn = failMsgFn or defaultFailMsg

    return function(...)
        if yourAssert(...) then
            asserts.successes = asserts.successes + 1
        else
            local info = debug.getinfo(2, "S")
            local lineinfo = debug.getinfo(2, "l")
            local file = color.file(normalizeRelativePath(info.short_src))
            local line = color.line(lineinfo.currentline)
            local location = fmt('%s:%s: ', file, line)
            insert(asserts.failed, failMsgFn(location, pluginConfig, ...))
        end
    end
end

-- The main (currently only) assertion function is `equals`, aliased to `eq`,
-- which compares two values for equality. This is a deep comparison, meaning
-- that tables are compared recursively.
export.assert.equals = export.assert.create(deepEquals, equalsFailMsg)
export.assert.eq = export.assert.equals -- alias

--------------------------------------------------------------------------------------
-- Runs the tests, outputting the results in one of several ways,
-- depending on the configuration table.
function export.run(config, configDefaults)
    config = args.verify(config, argsMerged, argsMergedDefaults, configDefaults)

    if config.help then
        writef('A Lua test suite written with Loon.\n')
        writef('%s %s   %s', color.pass('--output'), color.value('"terminal|junit"'), 'choose the output format (default: terminal)')
        writef('%s                 %s', color.pass('--uncolored'), 'disable colors (default: off)')
        writef('%s                     %s', color.pass('--terse'), 'skip printing passing tests (default: off)')
        writef('%s                     %s', color.pass('--times'), 'note times in junit output (default: on)')
        writef('%s                      %s', color.pass('--help'), 'print this message')
        os.exit(0)
    end

    local outputs = {
        terminal = runTerminal,
        junit = runJunit
    }

    local result = outputs[config.output](config)
    reset()
    return result
end

return export
