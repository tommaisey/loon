local args = require('loon.args')
local test = require('loon')
local snap = require('loon.snap')
local eq = test.assert.equals
local err = test.assert.error.matches

local function verify(array, spec, defaults, userDefaults, abbreviations)
    array[-1] = 'lua'
    array[0] = 'my-script-name.lua'
    return args.verify({
        config = array,
        spec = spec,
        defaults = defaults,
        userDefaults = userDefaults,
        abbreviations = abbreviations
    })
end

snap.config(arg, {dir = 'tests/snapshots/args'})

-----------------------------------------------------------------
test.suite.start('command line arguments')
test.suite.start('parsing')

test.add('two booleans', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}}
    }
    local ex = {one = true, two = true}

    eq(verify({'--one', '--two'}, spec), ex)
end)

test.add('booleans mixed with values', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}},
        three = {options = {'a', 'b'}},
    }
    local exA = {one = true, two = true, three = "a"}
    local exB = {one = true, two = true, three = "b"}

    eq(verify({'--one', '--three', 'a', '--two'}, spec), exA)
    eq(verify({'--one', '--three', 'b', '--two'}, spec), exB)
    eq(verify({'--one', '--two', '--three', 'b'}, spec), exB)
    eq(verify({'--three', 'b', '--one', '--two'}, spec), exB)
end)

test.add('values supplied with = syntax', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}},
        three = {options = {'a', 'b'}},
    }
    local exA = {one = true, two = true, three = "a"}
    local exB = {one = true, two = true, three = "b"}

    eq(verify({'--one', '--three=b', '--two'}, spec), exB)
    eq(verify({'--one', '--three=a', '--two'}, spec), exA)
    eq(verify({'--one', '--three="a"', '--two'}, spec), exA)
    eq(verify({'--one', '--three="b"', '--two'}, spec), exB)
    eq(verify({'--one', '--three=\'a\'', '--two'}, spec), exA)
    eq(verify({'--one', '--three=\'b\'', '--two'}, spec), exB)
end)

test.add('value containing = is preserved', function()
    local spec = {
        flag = {options = {true, false}},
        other = {options = {true, false}},
        expr = {options = 'string'},
        tail = {options = 'string'},
    }
    eq(verify({'--flag', '--expr=a=b'}, spec), {flag = true, expr = 'a=b'})
    eq(verify({'--expr=x=y=z'}, spec), {expr = 'x=y=z'})

    -- A =-value arg must not consume the following arg.
    eq(verify({'--expr=a=b', '--flag'}, spec), {flag = true, expr = 'a=b'})
    eq(verify({'--expr=a=b', '--tail', 'after'}, spec),
        {expr = 'a=b', tail = 'after'})
    eq(verify({'--expr=a=b', '--flag', '--other'}, spec),
        {flag = true, other = true, expr = 'a=b'})
end)

test.add('booleans supplied with = syntax', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}},
        three = {options = {true, false}},
    }

    eq(verify({'--one', '--two', 'false', '--three'}, spec), {one = true, two = false, three = true})
    eq(verify({'--one', '--two', '--three', 'false'}, spec), {one = true, two = true, three = false})
    eq(verify({'--one=false', '--two=false', '--three', 'false'}, spec), {one = false, two = false, three = false})
    eq(verify({'--one="false"', '--three', '"false"'}, spec), {one = false, three = false})

    eq(verify({'--one=on', '--two=off', '--three', 'off'}, spec), {one = true, two = false, three = false})
    eq(verify({'--one=no', '--two=yes', '--three', 'yes'}, spec), {one = false, two = true, three = true})
end)

test.add('values supplied as number', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}},
        three = {options = {4, 5}},
    }
    local ex4 = {one = true, two = true, three = 4}
    local ex5 = {one = true, two = true, three = 5}

    eq(verify({'--one', '--three=4', '--two'}, spec), ex4)
    eq(verify({'--one', '--three', '4', '--two'}, spec), ex4)
    eq(verify({'--one', '--three', '"4"', '--two'}, spec), ex4)
    eq(verify({'--one', '--three', "'4'", '--two'}, spec), ex4)
    eq(verify({'--one', '--three=5', '--two'}, spec), ex5)
    eq(verify({'--one', '--three="4"', '--two'}, spec), ex4)
    eq(verify({'--one', '--three="5"', '--two'}, spec), ex5)
    eq(verify({'--one', '--three=\'4\'', '--two'}, spec), ex4)
    eq(verify({'--one', '--three=\'5\'', '--two'}, spec), ex5)
end)

test.add('detects arg table by interpreter at any negative index', function()
    local spec = {one = {options = {true, false}}}
    local ex = {one = true}

    -- arg[-1] commonly holds the interpreter as a full path on POSIX/Windows.
    local fullPath = {'--one'}
    fullPath[-1] = '/usr/bin/lua5.4'
    fullPath[0] = 'my-script-name.lua'
    eq(args.verify({config = fullPath, spec = spec}), ex)

    local winPath = {'--one'}
    winPath[-1] = 'C:\\Program Files\\Lua\\lua.exe'
    winPath[0] = 'my-script-name.lua'
    eq(args.verify({config = winPath, spec = spec}), ex)

    local luajit = {'--one'}
    luajit[-1] = 'luajit'
    luajit[0] = 'my-script-name.lua'
    eq(args.verify({config = luajit, spec = spec}), ex)

    -- Interpreter flags can occupy -1; the real interpreter sits further back.
    local withFlags = {'--one'}
    withFlags[-3] = '/usr/bin/lua'
    withFlags[-2] = '-e'
    withFlags[-1] = 'some code'
    withFlags[0] = 'my-script-name.lua'
    eq(args.verify({config = withFlags, spec = spec}), ex)

    -- A plain config table (no negative indices) must NOT be treated as args.
    eq(args.verify({config = {one = true}, spec = spec}), ex)
end)

test.add('quotes inside a value are preserved', function()
    local spec = {expr = {options = 'string'}}

    -- Apostrophe in the middle of an unquoted value.
    eq(verify({'--expr=it\'s'}, spec), {expr = "it's"})
    eq(verify({'--expr', 'it\'s'}, spec), {expr = "it's"})

    -- Embedded double-quote in an unquoted value.
    eq(verify({'--expr=a"b'}, spec), {expr = 'a"b'})

    -- A matched outer pair is still stripped, but only the outer pair.
    eq(verify({'--expr="a\'b"'}, spec), {expr = "a'b"})
    eq(verify({'--expr=\'a"b\''}, spec), {expr = 'a"b'})
end)

test.add('negative number value is not mistaken for a flag', function()
    local spec = {
        flag = {options = {true, false}},
        count = {options = 'number'},
        amount = {options = 'number'},
    }

    eq(verify({'--count', '-5'}, spec), {count = -5})
    eq(verify({'--count', '-5', '--flag'}, spec), {count = -5, flag = true})
    eq(verify({'--flag', '--count', '-5'}, spec), {count = -5, flag = true})
    eq(verify({'--amount', '-3.14'}, spec), {amount = -3.14})

    -- A real flag immediately after must still be treated as a flag.
    eq(verify({'--flag', '--count', '7'}, spec), {flag = true, count = 7})
end)

test.suite.stop('parsing')
test.suite.start('verification')

test.add('types and options', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {'hi', 'bye'}},
        three = {options = {4, 5}},
        four = {options = 'number'}
    }

    err("%-%-one was 'hello' but should be 'true/on/yes' or 'false/no/off'", function()
        verify({'--one', 'hello'}, spec)
    end)

    err("%-%-two was 'fi' but should be one of: hi, bye", function()
        verify({'--two', 'fi'}, spec)
    end)

    err("'bye' cannot be parsed as a flag or option", function()
        verify({'--two', 'hi', 'bye'}, spec)
    end)

    err("%-%-three was 'yo' but should be one of: 4, 5.", function()
        verify({'--three', 'yo'}, spec)
    end)

    err("%-%-four has type 'string' %(yo%) but it should be a 'number'", function()
        verify({'--four', 'yo'}, spec)
    end)

    err("'%-%-two=' is a malformed argument with '=' syntax", function()
        verify({'--two=', 'yo'}, spec)
    end)
    err("'%-%-=yo' is a malformed argument with '=' syntax", function()
        verify({'--=yo'}, spec)
    end)

    -- Fuzzy match suggestions
    err("'--oned' is an unrecognized argument. Did you mean 'one'?", function()
        verify({'--oned', '--three'}, spec)
    end)

    err("'--five' is an unrecognized argument.", function()
        verify({'--five', '--three'}, spec)
    end)
end)

test.suite.stop('verification')
test.suite.start('defaults')

test.add('system defaults', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}},
        three = {options = {4, 5}},
    }
    local defaults = {
        one = true,
        three = 5
    }
    local ex5 = {one = true, three = 5}
    local ex4 = {one = true, three = 4}

    eq(verify({}, spec), {}, 'without defaults')
    eq(verify({}, spec, {}), {}, 'empty defaults')
    eq(verify({}, spec, defaults), ex5, 'with defaults')
    eq(verify({'--three=5'}, spec, defaults), ex5, 'same as default')
    eq(verify({'--three=4'}, spec, defaults), ex4, 'overridden')
end)

test.add('user defaults', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}},
        three = {options = {4, 5}},
        user = {options = 'string'},
    }
    local defaults = {
        one = true,
        three = 5
    }
    local userDefaults = {
        user = 'hello'
    }
    local ex = {one = true, three = 5}
    local exuser = {one = true, three = 5, user = 'hello'}

    eq(verify({}, spec, defaults, {}), ex, 'with empty user defaults')
    eq(verify({}, spec, defaults, userDefaults), exuser, 'with user defaults')
end)

test.suite.stop('defaults')
test.suite.start('abbreviations')

test.add('single letter', function()
    local spec = {
        argA = {options = {true, false}},
        argX = {options = {true, false}},
        argB = {options = {4, 5}},
    }
    local abbreviations = {
        a = 'argA',
        b = 'argB',
    }

    eq(verify({'-a'}, spec, nil, nil, abbreviations), {argA = true}, 'with single flag')
    eq(verify({'-b', '5'}, spec, nil, nil, abbreviations), {argB = 5}, 'with single argument')
    eq(verify({'-a', '-b', '5'}, spec, nil, nil, abbreviations), {argA = true, argB = 5}, 'with argument and flag (1)')
    eq(verify({'-b', '5', '-a'}, spec, nil, nil, abbreviations), {argA = true, argB = 5}, 'with argument and flag (2)')

    err("'%-k' is an unrecognized argument", function()
        verify({'-k'}, spec, nil, nil, abbreviations)
    end)

    err("'%--k' is an unrecognized argument. Did you mean %-k?", function()
        verify({'--k'}, spec, nil, nil, abbreviations)
    end)

    err("--argB was '7' but should be one of: 4, 5", function()
        verify({'-b', '7', '-a'}, spec, nil, nil, abbreviations)
    end)
end)

test.suite.stop('abbreviations')
test.suite.start('help')

test.add('help description', function()
    local spec = {
        one = {options = {true, false}},
        two = {options = {true, false}, desc = 'some description'},
        three = {options = {4, 5}, desc = 'another description'},
        four = {options = 'number', required = true},
        five = {options = 'string'},
        six = {options = {'choiceA', 'choiceB'}},
        seven = {options = {'anotherA', 'anotherB'}, desc = 'yet another description', required = true},
    }
    local defaults = {
        one = true,
        three = 5,
        five = 'hello',
        six = 'choiceB',
    }

    snap.output('args help description (basic)', function()
        args.describe({spec = spec, defaults = defaults})
    end)

    snap.output('args help description (uncolored)', function()
        args.describe({spec = spec, defaults = defaults, uncolored = true})
    end)

    snap.output('args help description (title)', function()
        args.describe({spec = spec, defaults = defaults, helpTitle = 'A custom help title'})
    end)

    snap.output('args help abbreviations', function()
        local abbrevs = {
            a = 'three',
            b = 'five',
            c = 'six'
        }

        args.describe({spec = spec, defaults = defaults, abbreviations = abbrevs})
    end)
end)

test.run(arg)
