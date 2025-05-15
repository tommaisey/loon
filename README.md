# loon

![test-all](https://github.com/tommaisey/loon/actions/workflows/test.yml/badge.svg)

`loon` is a test library for the Lua programming language, with the following goals:

- Small (~1000 lines of Lua without comments)
- Zero external dependencies (embeds [`serpent`](https://github.com/pkulchenko/serpent) for pretty-printing)
- Simple and attractive API, with no globals
- Equally easy to run from the terminal or programatically
- Beautiful output
- Assertion failures don't halt tests
- Snapshot testing facility
- Support for Lua 5.4 and 5.1 (for LuaJIT)

There are of course several other Lua test libraries, I simply wanted one with this
set of goals and trade-offs, and couldn't find exactly what I was looking for.

Here's an example of the output you get when running `loon` tests from the terminal:

<img width="486" alt="loon-output" src="https://github.com/user-attachments/assets/ebc9d2fe-e1c5-4687-8d5e-7c7a7d56a60a">

Beware: this library is currently a work in progress. Please post any issues you discover.

# examples

## basics

Let's start with a simple example.

```lua
local test = require('loon')

test.add('my first test', function()
    test.assert.eq(1 + 1, 2, 'must have integer addition')
    test.assert.eq(0 - 1, -1, 'must have signed integer addition')
end)

test.run()
```

To run the tests, you simply call the file in the usual way with Lua's interpreter.
This will print the results of the tests to the terminal, nicely colorized.

```sh
$ lua tests/my-tests.lua
```

If you want to control the output more, you can do that one of two ways.

You can pass a config table to the `run()` function, or you can pass the
Lua `arg` global, which contains the command-line arguments. You can combine
these approaches, taking configuration from the command-line or a fallback
config for items that weren't specified.

``` lua
-- explicit config: no colors and printing failing tests only
test.run({uncolored = true, terse = true})
-- using command-line arguments.
-- the options above would translate as: 'lua tests/my-tests.lua --uncolored --terse'
test.run(arg)
-- using command-line arguments with default fallbacks if not specified
test.run(arg, {uncolored = true, terse = true})
```

To find out which arguments are supported, you can run with the `--help` flag.

```sh
$ lua tests/my-tests.lua --help
```

## assertions

A small suite of assertions are shipped with `loon`, and it's important that you use
assertions that integrate with `loon` for the best reporting (regular `assert()` will
cause a test to fail, but the output won't be very readable).

You can define custom assertions quite easily (see the [custom assertions](#custom-assertions)
section for more), so we keep the default choices lightweight and general.

All assertions are in the `assert` sub-table of the main `loon` module.
Some assertions have aliases so you can choose the version that fits with your style.
Of course you can define your own local aliases if you prefer.

```lua
local test = require('loon')

test.add('assertion types', function()
    -- the main equality check
    test.assert.equals(2, 2, 'optional message')
    test.assert.eq(2, 2, 'alias for equals')

    -- equals does deep-comparison of tables:
    test.assert.eq({a = 1, b = {c = 2}}, {a = 1, b = {c = 9}}, 'this will fail')

    -- check for `true`, `false`, `nil`, and 'truthy' (meaning not `nil` or `false`
    -- since we can't use the keywords we prefix with 'is', and provide aliases
    -- for snake_case and camelCase aficionados.
    test.assert.truthy('yep', 'optional message')
    test.assert.is_true(true, 'optional message')
    test.assert.isTrue(true, 'optional message')

    test.assert.falsey(nil, 'optional message') -- also ok if it's `false`
    test.assert.is_false(false, 'optional message')
    test.assert.isFalse(false, 'optional message')

    test.assert.is_nil(nil, 'optional message')
    test.assert.isNil(nil, 'optional message')

    -- checks that a number is close to another number (within a tolerance factor)
    test.assert.near(5.1, 5, 0.2, 'optional message')
    test.assert.nearly(5.1, 5, 0.2, 'alias for near')

    -- checks that a string contains another string.
    -- the test string may be a Lua pattern if you need more flexibility.
    test.assert.string.contains('hello world', 'world')
    test.assert.string.contains('hello world', '[Ww]orld')

    -- checks that an error is thrown, and it contains the expected string.
    -- the string may be a Lua pattern if you need more flexibility.
    test.assert.error.contains('[Ee]xpected [Ss]tring', function()
        somethingThatShouldThrowAnError()
    end)
end)
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

test.run(arg)
```

If you don't want to indent all the tests inside a suite, you can use matching statements
of `suite.start` and `suite.stop`.
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

test.suite.stop('second suite') -- optional: the `run()` below stops the suite
test.run(arg)
```

A call to `test.run()` closes any open suites, even when running tests grouped by files,
so any calls to `test.suite.stop()` just before a `test.run()` call are optional.

## grouping by file

Commonly we want to split our tests into separate files, and optionally run them all together.
This is simple with `loon`, you can simply create a file with a call to `test.grouped()`
where each argument points to a file containing tests.

The arguments should use the same string format you might use to pass to `require`.
This means that if you put your tests into a directory called `my-tests` and you
expect to run them from the root of your project, you should use `'my-tests.file-name'`
to run the `my-tests/file-name.lua` tests.

You can then run tests on an individual file basis or all together, simply by running
the files in the normal way. `loon` is smart, and if tests are run via `test.grouped()`,
all the tests will be collected and then run as one collection. It's therefore a good
idea to make sure each file begins with a suite directive, so that the output indicates
which tests belong to which file.

An example follows below. The commands it allows you to run look like this:

``` sh
$ lua my-tests/all-tests.lua # run all tests.
$ lua my-tests/first-file.lua # run a single file of tests.

$ lua my-tests/all-tests.lua --output=junit # you can pass arguments
$ lua my-tests/second-file.lua --output=junit # you can pass them in this case too
```

And here are the files in the `my-tests` directory which allow this:

```lua
-- my-tests/first-file.lua
local test = require('loon')

test.suite.start('first suite')

test.add('test one', function()
    test.assert.eq(1 + 1, 2, 'must be in a euclidean universe')
end)

test.run(arg)

-- my-tests/second-file.lua
local test = require('loon')

test.suite.start('second suite')

test.add('test two', function()
    test.assert.eq(2 + 2, 4, '2 + 2 must equal 4')
end)

test.run(arg)

-- my-tests/all-tests.lua
local test = require('loon')

test.grouped(
    'my-tests.first-file',
    'my-tests.second-file'
)

test.run(arg)
```

## snapshot tests

The main `loon` module allows you to write unit tests, but another useful paradigm
is 'snapshot' testing. This means that you write some code that should produce an
output, and then you compare it against a validated output that you have committed
into your repository. This ensures that output produced by a given input stays the
same. It's helpful when your code produces complex and potentially varied output,
because it automates the process of creating and comparing validated results.

`loon` includes a built-in facility for snapshot tests which are written as a
'plugin' (more on plugins later). We use these tests extensively to test `loon`
itself. To use it, you must include the `loon.snap` module, which includes
special assertion functions to compare snapshots and/or create them (if you
supply the `--update` flag).

```lua
local myCode = require('code-i-want-to-test')
local test = require('loon')
local snapshot = require('loon.snap')

-- configure the snapshot tester.
-- you MUST provide the directory where the snapshots are stored.
-- you could do this via a command line argument e.g. '--dir my-tests/snapshots'.
-- but it's often convenient to provide it in the code by default.
snapshot.config(arg, {dir = "my-tests/snapshots"})

test.suite.start('my snapshot tests')

test.add('my first snapshot test', function()
    -- compares the stored file contents to the value returned by your function
    snapshot.compare('name that must be unique', myCode.thatReturnsOutput())
end)

test.add('my second snapshot test', function()
    -- compares the stored file contents to whatever your function writes to io.output()
    snapshot.output('a name that describes the test', function()
        io.output():write('this will be in the snapshots')
        io:write('so will this: io.write("x") is equivalent to io.output():write("x")')
        print('so will this: print() also uses io.output()')
        myCode.thatWritesToIoOutput() -- so will this, if it calls any of the above
    end)
end)

test.run(arg)
```

As you can see, this looks similar to a normal `loon` test file, but it includes
the `loon.snap` module, configures it, and then uses the assertions that it provides
in the tests.

The `compare()` assertion uses the data that you pass to it as an argument.

The `output()` assertion captures anything that is written to Lua's default output
stream `io.output()` and compares it with the file. This means that it captures
anything written with `print()` or explicitly with `io.output():write(x)` or
`io:write(x)`. This is very useful for testing command-line output.

Snapshots are saved using the format `[directory specified by --dir]/[name given to assertion].snap`.
This means that the name given to `compare()` or `output()` must be unique for
a given directory configuration. You can re-configure the the directory whenever
you want, but usually you'll do it at the top of a file. Choosing a unique directory
for each test file means that the names must only be unique within that test file.
You'll be warned if a directory/name combination is used twice during a test run.

``` lua
-- my-tests/file-one.lua
local test = require('loon')
local snapshot = require('loon.snap')
snapshot.config(arg, {dir = "my-tests/snapshots/file-one"})

test.suite.start('file one snapshots')

test.add('first test', function()
    snapshot.compare('must be unique in this file', myCode.thatReturnsOutput())
end)

test.run(arg)

-- my-tests/file-two.lua
local test = require('loon')
local snapshot = require('loon.snap')
snapshot.config(arg, {dir = "my-tests/snapshots/file-two"})

test.suite.start('file two snapshots')

test.add('first test', function()
    -- it's ok that this has the same name, because it has its own snapshot directory
    snapshot.compare('must be unique in this file', myCode.thatReturnsOutput())
end)

test.run(arg)
```

When you first run your snapshot tests, none of the snapshots will exist yet, so
all of the tests will fail. There's an easy way to create the snapshots: just supply
the `--update` flag. This is also used to update snapshots when the outputs have
changed in a way that you expect and are happy with.

```sh
$ mkdir -p my-tests/snapshots/file-one # make the directory first!
$ lua my-tests/file-one.lua --update # create/update the snapshots
```

This command will run the tests, tell you how many new and failed tests
there are, and ask if you want to proceed with updating them. If you
answer `Y [enter]`, then you will be shown the diff of each test in turn
and asked if you're happy with the new results. If you answer `Y [enter]`,
then that snapshot will be stored and you'll move onto the next change.

If you're unhappy with any changes, select `N` and you can go back and
edit your code until you are. Once you've accepted all the changes, the
tests will pass, and you should commit the new snapshots to your repository.

## plugins

`loon` is written to be extensible, so that you can create custom test
runners with extra behavior. These can run seamlessly alongside the
other tests in your suites, and benefit from unified formatting and
error reporting.

The `loon.snap` module itself is written as such a plugin, and is the
main motivation for the plugin system, but if you have some
interesting use-case you might want to try it yourself.

### custom assertions

The easiest way to customize `loon` is to make your own assertion
functions. These can run inside any normal loon test and have
custom error messages.

```lua
local loon = require('loon')

local function equalIgnoringCase(a, b)
    if type(a) ~= type(b) or type(a) ~= 'string' then
        return false
    end

    return a:lower() == b:lower()
end

local function ignoringCaseFailMsg(srcLocation, a, b)
    if type(a) ~= type(b) or type(a) ~= 'string' then
        return string.format('%s expected two strings, got: %q and %q', srcLocation, type(a), type(b))
    end

    return string.format('%s strings not equal (ignoring case): %q vs. %q', srcLocation, a, b)
end

-- We'll return a module so this can be required from your test files.
return {
    equalIgnoringCase = loon.assert.create(equalIgnoringCase, ignoringCaseFailMsg)
}
```

### custom reporting and arguments

Sometimes you need to make a more full-featured plugin, which needs
configuration and may include custom summaries. Note that the APIs
shown here are not guaranteed to be stable since `loon` isn't yet
fully mature.

You might also find it useful to read the source of `loon/snap.lua`
for another example, and `loon/init.lua` if you want to see how the
guts work.

Here's a simple plugin example using the API at time of writing.

```lua
local loon = require('loon')
local args = require('loon.args') -- argument parser tool
local myModule = {}
local numFailuresInMyPlugin = 0

local function myAssertion(a, b)
    -- This is custom data configured by your plugin, see `config()` below.
    -- The reason it's accessed this way is so that your plugin can be configured
    -- multiple different times (e.g. in different files) without getting conflicted.
    -- This data will always represent the configured data as it was at the time
    -- when the test containing this assertion was defined. It's a bit roundabout,
    -- but we've found it useful (necessary, actually) in the snapshot plugin.
    local customData = assert(loon.plugin.getCustomData())
    return a == b and a ~= customData
end

local function myFailMsg(srcLocation, a, b)
    -- Let's note some information we'll use in a custom summary.
    numFailuresInMyPlugin = numFailuresInMyPlugin + 1

    return string.format(
        '%s: got: %s, expected: %s. Custom config is: %s. Custom failures so far: %s',
        srcLocation,
        a, b,
        loon.plugin.getCustomData(), -- 'bloop' or 'blah', as above
        numFailuresInMyPlugin
    )
end

-- The custom assertion provided by this plugin.
myModule.assertion = loon.assert.create(myAssertion, myFailMsg)

function myModule.config(configOrArgs, configDefaults)
    -- Specify any custom arguments that your plugin might want to consume.
    -- This means that they won't be flagged as 'unrecognised' if they also
    -- get passed to a call to `loon.run()` if we're running amongst other
    -- non-plugin tests.
    local customArguments = {myArgName = {true, false}}
    local customArgumentDefaults = {myArgName = false}
    local customArgumentAbbreviations = {m = 'myArgName'}

    -- Use the built-in argument parser to extract and verify your custom
    -- arguments into a table.
    local config = args.verify({
        pluginName = 'myPluginName',
        config = configOrArgs,
        spec = customArguments,
        defaults = customArgumentsDefaults,
        userDefaults = configDefaults,
        ignoreUnrecognized = true
    })

    -- This config data will be available to your assertions and/or failure message
    -- functions if they need it, by calling `loon.plugin.getCustomData()`.
    -- See the explaination above in `myAssertion()`.
    local pluginConfig = config.myArgName and 'blah' or 'bloop'

    -- Ok, now we can configure the `loon` runner to accept our custom arguments
    -- and to store the right custom data along with any subsequently defined tests.
    loon.plugin.config({
        arguments = customArguments,
        defaults = customArgumentDefaults,
        abbreviations = customArgumentAbbreviations,
        customData = pluginConfig
    })

    -- A summary function that runs after all the tests have run.
    -- Use this to print any custom messages you might have.
    -- The name is important to de-duplicate summary functions,
    -- so make sure it's something that will be unique to your
    -- test runner to avoid conflicts.
    loon.plugin.summary('my custom test summary', function()
        print(string.format('failures in custom module: %s', numFailuresInMyPlugin))
    end)

    -- It's important to reset any mutable state you might have last,
    -- in a summary function. This allows multiple test runs to happen
    -- in a single
    loon.plugin.summary('my custom test reset', function()
        numFailuresInMyPlugin = 0
    end)
end

return myModule
```
