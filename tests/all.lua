local test = require('loon')

test.grouped(
    'tests.args',
    'tests.color',
    'tests.terminal-output',
    'tests.junit-output'
)

-- The description only turns up when running with the --help flag
os.exit(test.run(arg, {helpTitle = "Loon's own test suite."}))
