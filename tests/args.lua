local args = require('loon.args')
local test = require('loon')
local eq = test.assert.equals

local function verify(array, spec, defaults)
    array[-1] = 'lua'
    array[0] = 'my-script-name.lua'
    return args.verify(array, spec, defaults)
end

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

test.run(arg)