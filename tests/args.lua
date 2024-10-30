local args = require('loon.args')
local test = require('loon')
local snap = require('loon.snap')
local eq = test.assert.equals

local function verify(array, spec, defaults, userDefaults)
    array[-1] = 'lua'
    array[0] = 'my-script-name.lua'
    return args.verify({
        config = array,
        spec = spec,
        defaults = defaults,
        userDefaults = userDefaults
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
    eq(verify({'-one', '-two'}, spec), ex)
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
    eq(verify({'--one', '--three=5', '--two'}, spec), ex5)
    eq(verify({'--one', '--three="4"', '--two'}, spec), ex4)
    eq(verify({'--one', '--three="5"', '--two'}, spec), ex5)
    eq(verify({'--one', '--three=\'4\'', '--two'}, spec), ex4)
    eq(verify({'--one', '--three=\'5\'', '--two'}, spec), ex5)
end)

test.suite.stop('parsing')
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
        args.describe(spec, defaults)
    end)

    snap.output('args help description (uncolored)', function()
        args.describe(spec, defaults, 'uncolored')
    end)

    snap.output('args help description (title)', function()
        args.describe(spec, defaults, false, 'A custom help title')
    end)
end)

test.run(arg)
