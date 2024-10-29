local test = require('loon')

test.grouped(
    'tests.args',
    'tests.color',
    'tests.terminal-output',
    'tests.junit-output'
)

test.run(arg)
