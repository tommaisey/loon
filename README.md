# loon

`loon` is a test library for the Lua programming language, with the following goals:

- Small, with zero external dependencies (embeds the `serpent` library for pretty-printing)
- Simple and attractive API, with no globals
- Equally easy to run from the terminal or programatically
- Beautiful output
- Assertion failures don't halt tests
- Snapshot testing facility

There are of course several other Lua test libraries, I simply wanted one with this
set of goals and trade-offs, and couldn't find exactly what I was looking for.

This library is current a work in progress.

# examples

## basics

Let's start with a simple example.

```lua
local test = require('loon')
local eq = test.assert.equals

test.add('my first test', function()
    eq(1 + 1, 2, 'must be in a euclidean universe')
    eq(0 - 1, -1, 'must have signed mathematics')
end)

test.run()
```

To run the tests, you simply call the file in the usual way with Lua's interpreter.
This will print the results of the tests to the terminal, nicely colorized.

```sh
$ lua tests.lua
```

If you want to control the output more, you can do that one of two ways.

You can pass a config table to the `run()` function, or you can pass the
Lua `arg` global, which contains the command-line arguments. You can combine
these approaches, taking configuration from the command-line or a fallback
config for items that weren't specified.

``` lua
-- explicit config
test.run({uncolored = true, terse = true})
-- use command-line arguments
test.run(arg)
-- use command-line arguments with default fallbacks
test.run(arg, {uncolored = true, terse = true})
```

To find out which arguments are supported, you can run with the `--help` flag.

```lua
$ lua tests/my-tests.lua --help

```

## suites

You can group your tests into suites, which can be nested.

```lua
local test = require('loon')

test.suite.add('first suite', function()
    test.add('test one', function()
        test.assert.eq(1 + 1, 2, 'must be in a euclidean universe')
    end)
end)

test.suite.add('second suite', function()
    test.add('test two', function()
        test.assert.eq(2 + 2, 4, '2 + 2 must equal 4')
    end)
end)

test.run()
```

If you don't want to indent all the tests inside a suite, you can use matching statements
of `suite.start` and `suite.stop`. However, you must be careful not to forget a `stop` statement.
This example results in exactly the same output as the first example.

```lua
local test = require('loon')

test.suite.start('first suite')

test.add('test one', function()
    test.assert.eq(1 + 1, 2, 'must be in a euclidean universe')
end)

test.suite.stop('first suite')

test.suite.start('second suite')

test.add('test two', function()
    test.assert.eq(2 + 2, 4, '2 + 2 must equal 4')
end)

test.suite.stop('second suite')

test.run()
```

If you prefer to split your tests into multiple files, each being a test suite, you can do so with `suite.file`,
which behaves just like Lua's `require`, but wraps the file into a test suite.

```lua
-- first-suite.lua
local test = require('loon')

test.add('test one', function()
    test.assert.eq(1 + 1, 2, 'must be in a euclidean universe')
end)

-- second-suite.lua
local test = require('loon')

test.add('test two', function()
    test.assert.eq(2 + 2, 4, '2 + 2 must equal 4')
end)

-- main.lua
test.suite.file('first-suite')
test.suite.file('second-suite')
test.run()
```

## config

When you run your tests, you can supply a config table of options, which are all optional.

```lua
tests.run({
    uncolored = true, -- don't output color in the terminal
    terse = true,     -- don't output succesful test titles
})
```
