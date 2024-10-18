local args = require('loon.args')
local test = require('loon')
local eq = test.assert.equals

local function verify(array, spec, defaults, userDefaults)
    array[-1] = 'lua'
    array[0] = 'my-script-name.lua'
    return args.verify(array, spec, defaults, userDefaults)
end

-----------------------------------------------------------------
test.suite.start('arg interpretation and validation')

test.add('two booleans', function()
    local spec = {
        one = {true, false},
        two = {true, false}
    }
    local ex = {one = true, two = true}

    eq(verify({'--one', '--two'}, spec), ex)
    eq(verify({'-one', '-two'}, spec), ex)
    eq(verify({'one', 'two'}, spec), ex)
end)

test.add('booleans mixed with values', function()
    local spec = {
        one = {true, false},
        two = {true, false},
        three = {'a', 'b'}
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
        one = {true, false},
        two = {true, false},
        three = {'a', 'b'}
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

test.add('values supplied as number', function()
    local spec = {
        one = {true, false},
        two = {true, false},
        three = {4, 5}
    }
    local ex4 = {one = true, two = true, three = 4}
    local ex5 = {one = true, two = true, three = 5}

    eq(verify({'--one', '--three=4', '--two'}, spec), ex4)
    eq(verify({'--one', '--three=5', '--two'}, spec), ex5)
    eq(verify({'--one', '--three="4"', '--two'}, spec), ex4)
    eq(verify({'--one', '--three="5"', '--two'}, spec), ex5)
    eq(verify({'--one', '--three=\'4\'', '--two'}, spec), ex4)
    eq(verify({'--one', '--three=\'5\'', '--two'}, spec), ex5)
end)

test.add('system defaults', function()
    local spec = {
        one = {true, false},
        two = {true, false},
        three = {4, 5}
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

test.add('system defaults', function()
    local spec = {
        one = {true, false},
        two = {true, false},
        three = {4, 5},
        user = 'string'
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

test.suite.stop('arg interpretation and validation')
test.run(arg)
