local color = require('loon.color')
local test = require('loon')
local eq = test.assert.equals
local contains = test.assert.string.contains
local falsey = test.assert.falsey

-----------------------------------------------------------------
test.suite.start('color')

test.add('without color', function()
    for name, c in pairs(color.no) do
        eq(c('here be text'), 'here be text', name)
    end
end)

test.add('with color', function()
    for name, c in pairs(color.yes) do
        contains(c('here be text'), 'here be text', name)
        falsey(c('here be text') == 'here be text', name)
    end
end)

test.run(arg)
