local loon = require('loon')
local export = {}

local args = require('loon.args')
local util = require('loon.util')
local colored = require('loon.color')
local color = colored.yes
-----------------------------------------------------------------------------
local argsBase = {
    dir = {options = 'string', desc = "snapshot storage directory", required = true},
    update = {options = {true, false}, desc = "interactively update snapshots"},
}

local argsBaseDefaults = {
    update = false,
}

local argsBaseAbbreviations = {
    d = 'dir',
    u = 'update'
}

-----------------------------------------------------------------------------
-- Cache some globals for speed.
local fmt = string.format
local insert = table.insert
local iowrite = io.write
local readAllFlag = util.luaversion > 52 and 'a' or '*a'
local readLineFlag = util.luaversion > 52 and 'l' or '*l'

local function writef(fstring, ...)
    iowrite(fmt(fstring, ...), '\n')
end
local function writefNoNewline(fstring, ...)
    iowrite(fmt(fstring, ...))
end

local function diff(actual, expectedPath)
    local tmpPath = os.tmpname()
    local file = assert(io.open(tmpPath, 'w+'), "test runner couldn't open temporary file")
    assert(file:write(actual))
    file:close()

    local diffHandle = io.popen(fmt('git diff "%s" "%s"', expectedPath, tmpPath))
    local text = assert(diffHandle, 'Could not run diff program'):read(readAllFlag)
    diffHandle:close()
    os.remove(tmpPath)
    return text
end

--------------------------------------------------------------------------------------
-- The stateful part of the library, so be careful!
local testNames = {}
local pass, fail, new, kind, ordered = {}, {}, {}, {}, {}

local function reset()
    pass, fail, new, kind, ordered = {}, {}, {}, {}, {}
end

--------------------------------------------------------------------------------------
local function compareVsFile(name, actual, transformer)
    local dir = assert(loon.plugin.getCustomData(), 'no snapshot directory set')
    local qualifiedName = dir .. ' ' .. name

    if testNames[qualifiedName] then
        writef('%s: duplicate snapshot name!\nonly one of these will run: \'%s\'', color.warn('warning'), name)
        return
    end

    testNames[qualifiedName] = true
    local path = dir .. name .. '.snap'
    local file = io.open(path, 'r')

    if transformer then
        actual = transformer(actual)
    end

    if file == nil then
        kind[name] = 'new'
        insert(new, {name = name, path = path, actual = actual})
        insert(ordered, {result = 'new', name = name})
        return false
    end

    local saved = file:read(readAllFlag)
    file:close()

    if saved == actual then
        kind[name] = 'pass'
        insert(pass, {name = name})
        insert(ordered, {result = 'pass', name = name})
        return true
    else
        kind[name] = 'fail'
        insert(fail, {name = name, path = path, actual = actual})
        insert(ordered, {result = 'fail', name = name, path = path, actual = actual})
        return false
    end
end

local function compareVsOutput(name, testFn, transformer)
    local path = os.tmpname()
    local outputPrev = io.output()
    local output = assert(io.open(path, 'w+'), "test runner couldn't open temporary file")
    io.output(output)

    local success, msg = pcall(testFn)

    io.output(outputPrev)
    output:close()

    if not success then
        -- throw error up to containing test
        error(msg)
    end

    output = io.open(path, 'r')
    local actual = output:read(readAllFlag)
    output:close()
    os.remove(path)

    return compareVsFile(name, actual, transformer)
end

local function failMsg(srcLocation, name, actual)
    if kind[name] == 'new' then
        return srcLocation .. fmt('new test: \'%s\'', name)
    end
    if type(actual) == 'function' then
        assert(ordered[#ordered].name == name)
        actual = ordered[#ordered].actual
    end
    local dir = assert(loon.plugin.getCustomData(), 'no snapshot directory set')
    local path = dir .. name .. '.snap'
    return srcLocation .. '\n' .. diff(actual, path)
end

local function runUpdate()
    local anyActionRequired = #fail > 0 or #new > 0
    local yes = color.pass('Y')
    local no = color.fail('N')

    if anyActionRequired then
        if #fail > 0 and #new > 0 then
            writefNoNewline(
                'snapshot actions required.\n%d %s tests and %d %s tests. proceed? %s/%s ',
                #new, color.pass('new'), #fail, color.fail('failed'), yes, no
            )
        elseif #fail > 0 then
            writefNoNewline(
                'snapshot actions required.\n%d %s tests. proceed? %s/%s ',
                #fail, color.fail('failed'), yes, no
            )
        else
            writefNoNewline(
                'snapshot actions required.\n%d %s tests. proceed? %s/%s ',
                #new, color.pass('new'), yes, no
            )
        end

        local answer = io.stdin:read(readLineFlag)

        if not answer or answer:find('[nN]') then
            writef('ok then, exiting...')
            return 1
        end
    end

    local function confirmAndWrite(answer, path, actual)
        if answer == nil or not answer:find('[yYnN]') then
            writef('could not understand your repsonse; exiting...')
            return false
        elseif answer:find('[nN]') then
            writef('looks like you have work to do; exiting...')
            return false
        end

        local file = assert(io.open(path, 'w+'), 'could not open path for writing: ' .. path)
        assert(file:write(actual))
        file:close()
        writef('%s: %s', color.pass('accepted'), color.file(path))
        return true
    end

    local beginDivide = color.msg('>>> begin new snapshot')
    local endDivide = color.msg('<<< end new snapshot')

    for _, elem in ipairs(new) do
        writef('==================================================')
        writef('%s\n%s%s', beginDivide, elem.actual, endDivide)
        writefNoNewline('\nnew test: %s.\napprove the snapshot now? %s/%s ',
            color.file(elem.name), yes, no
        )

        if not confirmAndWrite(io.stdin:read(readLineFlag), elem.path, elem.actual) then
            return 1
        end
    end

    for _, elem in ipairs(fail) do
        writef('==================================================')
        writefNoNewline(
            '%s\n\ntest has changes: %s\naccept changes? %s/%s ',
            diff(elem.actual, elem.path), color.file(elem.name), yes, no
        )

        if not confirmAndWrite(io.stdin:read(readLineFlag), elem.path, elem.actual) then
            return 1
        end
    end

    if anyActionRequired then
        writef('%s! all files up-to-date.', color.pass('done'))
    end

    return 0
end

--------------------------------------------------------------------------------------
-- The public part of the library

-- The function used to do a snapshot assertion inside a loon test.
-- It takes (name, result, [transformer]), where the result is the output your code
-- makes today. The result will be compared against a file in the
-- configured directory (see `config()`) with the filename `name`.
--
-- If you supply a 'transformer' function, the result will be run
-- through it before the comparison. You can use this to edit the
-- result before it is compared. You might do this to allow the
-- test to be run in multiple contexts - for example, if you
-- expect the output to contain a file path, you can replace
-- it with a common string so that the test doesn't depend
-- on the exact location of the file on your system.
export.compare = loon.assert.create(compareVsFile, failMsg)

-- Like `compare()`, except it captures anything written to `io.output()`
-- by `testFn` and uses that as the snapshot, instead of a string supplied
-- directly by you.
export.output = loon.assert.create(compareVsOutput, failMsg)

-- Configure the snapshot tests. This must be done before running any
-- snapshot tests, and it must configure the snapshot directory that
-- will be used.
function export.config(configOrArgs, configDefaults)
    local config = args.verify({
        config = configOrArgs,
        spec = argsBase,
        defaults = argsBaseDefaults,
        abbreviations = argsBaseAbbreviations,
        userDefaults = configDefaults,
        ignoreUnrecognized = true
    })

    assert(config.dir, 'you failed to configure the output directory.\n'
        .. 'pass the --dir argument at the terminal, or "dir" element in the config.')

    loon.plugin.config({
        pluginName = 'snapshots',
        arguments = argsBase,
        defaults = argsBaseDefaults,
        abbreviations = argsBaseAbbreviations,
        customData = config.dir:gsub('[\\/]$', '') .. '/'
    })

    loon.plugin.summary('snapshot: print new tests', function()
        if #new > 0 then
            writef('%s: %s tests', color.fail('new snapshots'), color.fail(#new))
        end
    end)

    if config.update then
        loon.plugin.summary('snapshot: update', runUpdate)
    end

    loon.plugin.summary('snapshot: reset self', reset)
end

-- Returns a function that normalizes stack traces by stripping line numbers,
-- normalizing relative paths (which Lua sometimes prefixes with './' and
-- sometimes doesn't, depending on context) and replacing a given list of
-- file names (the varargs) with '[path normalized for test]'.
--
-- It also normalizes some values found in error messages or stack traces,
-- like function representations that contain hex addresses (which are
-- unstable from run-to-run).
--
-- This is primarily for use in loon's own test suite, where we want to
-- test the output of loon itself, and don't want things like line
-- numbers or the particular top level file the tests were invoked from
-- to affect the outcome of terminal/junit output.
function export.normalizeStack(...)
    local files = {...}

    for i, name in ipairs(files) do
        -- escape pattern syntax:
        files[i] = name:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
    end

    return function(msg)
        for _, name in ipairs(files) do
            msg = msg:gsub(name .. ':%d+: in main chunk', '[[path normalized for test]]')
        end

        return msg
            :gsub('(:)%d+([:>])', '%1[--]%2') -- uncolored line numbers
            :gsub('(:[^m]+m)%d+([^m]+m[:>])', '%1[--]%2') -- colored line numbers
            :gsub('%./', '') -- relative path normalize
            :gsub('function: 0x%x+', 'function: [normalized for test]') -- function representation
    end
end

return export
