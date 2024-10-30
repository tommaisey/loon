local color = require('loon.color')
local test = require('loon')
local assert = test.assert
local fmt = string.format

-----------------------------------------------------------------
test.suite.start('color')

test.add('with color', function()
    local n = 0

    for name, c in pairs(color.yes) do
        n = n + 1
        local id = 'color.yes.' .. name
        assert.eq(type(c), 'function', fmt('%s is a function', id))
        assert.string.contains(c('hello world'), 'hello world', fmt('%s wraps the string', id))
        assert.falsey(c('hello world') == 'hello world', fmt('%s modifies the string', id))
    end

    assert.truthy(n >= 8, 'has some colors')
end)

test.add('ansi color', function()
    local n = 0

    for name, c in pairs(color.ansi) do
        n = n + 1
        local id = 'color.ansi.' .. name
        assert.eq(type(c), 'function', fmt('%s is a function', id))

        if name == "foreground" then
            assert.eq(type(c(47)), 'function', fmt('%s is a function producing functions', id))
            assert.eq(c(31)('hello'), color.ansi.red('hello'), fmt('%s is a produces ansi functions', id))
        else
            assert.string.contains(c('hello world'), 'hello world', fmt('%s wraps the string', id))
            assert.falsey(c('hello world') == 'hello world', fmt('%s modifies the string', id))
        end
    end

    assert.truthy(n >= 8, 'has some colors')
end)

test.add('without color', function()
    for name in pairs(color.yes) do
        local c = color.no[name]
        local id1, id2 = 'color.yes.' .. name, 'color.no.' .. name

        assert.truthy(c, fmt('%s corresponds to %s', id2, id1))
        assert.eq(c, tostring, fmt('%s is the tostring function', id2))
    end

    for name in pairs(color.ansi) do
        local c = color.no[name]
        local id1, id2 = 'color.ansi.' .. name, 'color.no.' .. name

        assert.truthy(c, fmt('%s corresponds to %s', id2, id1))
        assert.eq(c, tostring, fmt('%s is the tostring function', id2))
    end
end)

test.run(arg)
