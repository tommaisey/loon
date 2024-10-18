local export = {}

local args = require('loon.args')
local colored = require('loon.color')
local color = colored.yes
-----------------------------------------------------------------------------
local argspec = {
    dir = 'string',
    interactive = {true, false},
    uncolored = {true, false}
}

local argdefaults = {
    uncolored = false,
    interactive = false
}

-----------------------------------------------------------------------------
-- Cache some globals for speed.
local fmt = string.format
local tostring = tostring
local insert = table.insert
local iowrite = io.write

local function writef(fstring, ...)
    iowrite(fmt(fstring, ...), '\n')
end
local function writefNoNewline(fstring, ...)
    iowrite(fmt(fstring, ...))
end

-- Always indent by 2 spaces, don't indent initial line
local function indent(text)
    return text:gsub('\n', '\n  ')
end

local function diff(actual, expectedPath)
    local tmpPath = os.tmpname()
    local file = assert(io.open(tmpPath, 'w+'), "test runner couldn't open temporary file")
    file:write(actual)
    file:close()

    local diffHandle = io.popen(fmt('diff --color=always --context "%s" "%s"', expectedPath, tmpPath))
    local text = assert(diffHandle, 'Could not run diff program'):read('a')
    diffHandle:close()
    os.remove(tmpPath)
    return text
end

-----------------------------------------------------------------------------
local tests = {}
local testNames = {}

function export.test(name, actual)
    if testNames[name] then
        writef(
            '%s: duplicate test name: "%s".\nOnly one of these tests will run.',
            color.warn('Warning'), color.file(name)
        )
    else
        insert(tests, {name, tostring(actual)})
        testNames[name] = true
    end
end

local printResults, runInteractive

function export.run(config, configDefaults)
    config = args.verify(config, argspec, argdefaults, configDefaults)
    color = config.uncolored and colored.no or colored.yes
    assert(config.dir, 'you failed to configure the output directory. '
        .. 'pass the --dir argument at the terminal, or "dir" element in the config.')

    local dir = config.dir:gsub('[\\/]$', '') .. '/'

    local pass, fail, new, ordered = {}, {}, {}, {}

    for _, elem in ipairs(tests) do
        local name, actual = elem[1], elem[2]
        local path = dir .. name .. '.snap'
        local file = io.open(path, 'r')

        if file == nil then
            insert(new, {name = name, path = path, actual = actual})
            insert(ordered, {result = 'new', test = elem})
        else
            local saved = file:read('a')
            file:close()

            if saved == actual then
                insert(pass, elem)
                insert(ordered, {result = 'pass', test = elem})
            else
                insert(fail, {name = name, path = path, verified = saved, actual = actual})
                insert(ordered, {result = 'fail', test = elem, path = path, verified = saved, actual = actual})
            end
        end
    end

    if config.interactive then
        return runInteractive(ordered, pass, fail, new)
    else
        return printResults(ordered, pass, fail, new)
    end
end

function printResults(ordered, pass, fail, new)
    for _, elem in ipairs(ordered) do
        if elem.result == 'pass' then
            writef('%s %s', color.pass('+'), elem.test.name)
        elseif elem.result == 'fail' then
            writef('%s %s', color.fail('x'), elem.test.name)
            writef(indent(diff(elem.actual, elem.path)))
        elseif elem.result == 'new' then
            writef('%s %s', color.fail('new!'), elem.test.name)
        else
            error('logic error')
        end
    end

    writef('\n--------------------------')

    if #fail > 0 then
        writef('%s: %s tests', color.pass('pass'), color.pass(#pass))
        writef('%s: %s tests', color.fail('fail'), color.fail(#fail))

        if #new > 0 then
            writef('%s: %s tests', color.fail('new'), color.fail(#new))
        end
    else
        writef('%s: %s', color.pass('all tests pass'), color.pass(#pass))
    end

    return #fail
end

function runInteractive(_, pass, fail, new)
    local anyActionRequired = #fail > 0 or #new > 0
    local yes = color.pass('Y')
    local no = color.fail('N')

    if anyActionRequired then
        if #fail > 0 and #new > 0 then
            writefNoNewline(
                'actions required.\n%d %s tests and %d %s tests. proceed? %s/%s ',
                #new, color.pass('new'), #fail, color.fail('failed'), yes, no
            )
        elseif #fail > 0 then
            writefNoNewline(
                'actions required.\n%d %s tests. proceed? %s/%s ',
                #fail, color.fail('failed'), yes, no
            )
        else
            writefNoNewline(
                'actions required.\n%d %s tests. proceed? %s/%s ',
                #new, color.pass('new'), yes, no
            )
        end

        local answer = io.stdin:read('l')

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
        file:write(actual)
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

        if not confirmAndWrite(io.stdin:read('l'), elem.path, elem.actual) then
            return 1
        end
    end

    for _, elem in ipairs(fail) do
        writef('==================================================')
        writefNoNewline(
            '%s\n\ntest has changes: %s\naccept changes? %s/%s ',
            diff(elem.actual, elem.path), color.file(elem.name), yes, no
        )

        if not confirmAndWrite(io.stdin:read('l'), elem.path, elem.actual) then
            return 1
        end
    end

    if anyActionRequired then
        writef('%s! all files up-to-date.', color.pass('done'))
    else
        writef('%s: %s', color.pass('all tests pass'), color.pass(#pass))
    end

    return 0
end

return export
