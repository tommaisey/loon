-- This just exists so you can do require('loon')
-- once the parent directory of 'loon' is on the
-- package path.
--
-- The only reason we don't just require('loon.loon')
-- is that it makes functions in stack traces look like:
--   function 'loon.loon.run'
-- instead of:
--   function 'loon.run'
local source = debug.getinfo(1, 'S').source
local dir = assert(source:sub(2):match('^(.*[/\\])'),
    "loon/init.lua: couldn't determine own directory from " .. source)
return assert(loadfile(dir .. 'loon.lua'))()
