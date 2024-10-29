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

```sh
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
idea to make sure each file begins with a suite directive, so you can see in the output
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

test.suite.start('first suite')
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

The 'main' `loon` module allows you to write unit tests, but another useful paradigm
is called 'snapshot' testing. This means that you write some code that should produce
an output, and then you compare it against a validated output that you have committed
into your repository. These tests ensure that changes you make don't change any output
that users of your code may rely on.

`loon` includes a built-in facility for these kinds of tests which are written as a
'plugin' to `loon` (more on plugins later). We use these tests extensively to test
`loon` itself. To use it, you must include the `loon.snap` module, which includes
assertion functions that check against snapshots.

```lua
local myCode = require('code-i-want-to-test')
local test = require('loon')
local snapshot = require('loon.snap')

-- configure the snapshot tester.
-- you MUST provide the directory where the snapshots are stored.
-- you could do this via a command line argument e.g. '--dir my-tests/snapshots'.
-- but it's often convenient to provide this in the code by defaults.
snapshot.config(arg, {dir = "my-tests/snapshots"})

test.suite.start('my snapshot tests')

test.add('my first snapshot test', function()
    -- compares the value returned by your function to the stored file contents
    snapshot.compare('name that must be unique', myCode.thatReturnsOutput())
end)

test.add('my second snapshot test', function()
    -- compares whatever is written to to io.output() by the function you supply
    snapshot.output(a name that describes the test', function()
        io.output():write('this will be tested')
        io:write('io.write("x") is equivalent to io.output():write("x")')
        print('this writes to the same output, so is tested as well')
        myCode.thatWritesToIoOutput() -- custom code writing to the default output
    end)
end)

test.run(arg)
```

As you can see, this looks similar to a normal `loon` test file, but it includes
the `loon.snap` module, configures it, and then uses the assertions that it provides
in the tests.

The `compare` assertion uses the data that you pass to it as an argument.

The `output` assertion captures anything that is written to Lua's default output
stream `io.output()` and compares it with the file. This means that it captures
anything written with `print()` or explicitly with `io.output():write(x)` or
`io:write(x)`. This is very useful for testing command-line output.

You must ensure that every snapshot assertion that points at the same directory
has a unique name, and that it's a valid file name on the systems you will test
on, because the snapshots are saved into files with these names. It's usually
a good idea to configure the snapshots for each test file into a different
directory so that you don't have to worry about cross-file name conflicts.

``` lua
-- my-tests/file-one.lua
local test = require('loon')
local snapshot = require('loon.snap')

snapshot.config(arg, {dir = "my-tests/snapshots/file-one"})
test.suite.start('file one snapshots')

test.add('file one, first test', function()
    snapshot.compare('must be unique in this file', myCode.thatReturnsOutput())
end)

test.run(arg)

-- my-tests/file-two.lua
local test = require('loon')
local snapshot = require('loon.snap')

snapshot.config(arg, {dir = "my-tests/snapshots/file-two"})
test.suite.start('file one snapshots')

test.add('file two, first test', function()
    -- it's ok that this has the same name, because it has its own snapshot directory
    snapshot.compare('must be unique in this file', myCode.thatReturnsOutput())
end)

test.run(arg)
```

When you first write your snapshot tests, none of the snapshots will yet exist, so
all of the tests will fail. There's an easy way to create the snapshots, and also
to update them when the outputs have changed in a way that you expect and are
happy with. Just supply the `--update` flag at the command line.

```sh
$ mkdir -p my-tests/snapshots/file-one # make the directory first!
$ lua my-tests/file-one.lua --update # create/update the snapshots
```

This command will run the tests, tell you how many failed tests and new tests
there are, and ask you if you want to proceed with updating them. If you
answer `Y [enter]`, then you will be shown the diff of each test in turn
and asked if you're happy with the new results. If you answer `Y [enter]`,
then that snapshot will be stored and you'll move onto the next change.

If you're unhappy with any changes, you can go back and make changes to
your code until you are. Once you've accepted all the changes, the tests
will pass, and you should commit the new snapshots to your repository.

Overall snapshot tests can be really useful for ensuring your program's
output doesn't change at a high level, especially when the output is
too complex to write by hand as a unit test comparison. This is why
we use it to test `loon` itself - we want to ensure that output to
the terminal (and other formats) doesn't change without us knowing
about it!

## plugins

`loon` is written to be extensible, so that you can create custom test
runners with extra behavior, which hook seamlessly into the test system
you use for your other tests. The `loon.snap` module itself is written
as such a plugin, which was the main motivation for it, but if you have
some interesting use-case you might want to try this yourself.

However, take note! Loon isn't yet fully mature, and the plugin API is
not guaranteed to be stable as a result. We also don't have detailed
documentation for it, but you can read the below example plugin if
you want to give it a go. You might also find it useful to read the
source of `loon/snap.lua` for another example, and `loon/init.lua`
if you want to see how the guts work.

So here's a simple plugin example using the API at time of writing.

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
    -- when the test this assertion live in was defined. It's a bit roundabout,
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

-- This becomes a function with the same signature as `myAssertion()`.
-- Consumers of the plugin can use it inside tests to
myModule.assertion = loon.assert.create(myAssertion, myFailMsg)

function myModule.config(configOrArgs, configDefaults)
    -- Specify any custom arguments that your plugin might want to consume.
    -- This means that they won't be flagged as 'unrecognised' if they also
    -- get passed to a call to `loon.run()` if we're running amongst other
    -- non-plugin tests.
    local customArguments = {myArgName = {true, false}}
    local customArgumentDefaults = {myArgName = false}

    -- Use the built-in argument parser to extract and verify your custom
    -- arguments into a table.
    local config = args.verify({
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
    loon.plugin.config(customArguments, customArgumentDefaults, pluginConfig)

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

## config

When you run your tests, you can supply a config table of options, which are all optional.

```lua
tests.run({
    uncolored = true, -- don't output color in the terminal
    terse = true,     -- don't output succesful test titles
})
```
