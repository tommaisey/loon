-- A library to assist verifying config tables and argument lists.
-- In our model, configuration can be done either way, with
-- loon.run(arg) or loon.run({stuff = true}), so we must
-- convert from argument lists to a config table, then
-- verify the table against a spec.
--
-- The spec is a table of keys to arrays of 'allowed' values.
local export = {}
local fmt = string.format
local insert = table.insert
local iowrite = io.write

local function arrayToString(array, separator, fn)
    local strs = {}
    fn = fn or function(x) return x end
    for _, value in ipairs(array) do
        insert(strs, fn(tostring(value)))
    end
    return table.concat(strs, separator or ', ')
end

local function ofType(spec, typeString)
    if type(spec) == 'string' then
        return spec == typeString
    end

    for _, val in pairs(spec) do
        if type(val) ~= typeString then
            return false
        end
    end

    return true
end

local function contains(array, value)
    for _, val in pairs(array) do
        if val == value then
            return true
        end
    end

    return false
end

local function isArgsList(config)
    local idx = -1

    while(true) do
        local element = config[idx]

        if element == nil then
            return false
        elseif type(element) == 'string' and element:find('[Llua]') then
            return true
        end

        idx = idx - 1
    end
end

local function convertIfArgs(config, specs, ignoreUnrecognized)
    if config == nil then
        return {}
    elseif not isArgsList(config) then
        return config
    end

    local convertedConfig = {}
    local idx = 1

    while(true) do
        local item = config[idx]
        if item == nil then break end

        local value
        local isBooleanSwitch
        local name = item:match('^%-*(.+)$')
        assert(name, "malformed argument: " .. name)

        if name:find('=') then
            name, value = name:match('([^=]+)=([^=]+)')

            if not name or not value or #name == 0 or #value == 0 then
                error("malformed argument with '=' syntax: '" .. item .. "'")
            end

            idx = idx + 1
        else
            local nextItem = config[idx + 1]

            if nextItem ~= nil and not nextItem:find('^%-') then
                value = nextItem
                idx = idx + 2
            else
                isBooleanSwitch = true
                idx = idx + 1
            end
        end

        local spec = specs[name]

        if spec == nil then
            if not ignoreUnrecognized then
                error("unrecognized argument: " .. name)
            end
        else
            if value then
                value = value:match('["\']?([^"\']+)')
            end

            local options = assert(spec.options, 'spec item lacks options array')

            if ofType(options, 'boolean') then
                if value == nil then
                    value = assert(isBooleanSwitch) -- true
                else
                    if value == 'true' then
                        value = true
                    elseif value == 'false' then
                        value = false
                    else
                        error(fmt("expected 'true' or 'false' value for '%s', got: '%s'", name, value))
                    end
                end
            elseif ofType(options, 'number') then
                value = assert(tonumber(value), "couldn't convert argument to a number: " .. value)
            end

            convertedConfig[name] = value
        end
    end

    return convertedConfig
end

local function verifyWithSpec(config, specs)
    for k, spec in pairs(specs) do
        local element = config[k]
        local options = spec.options

        if element ~= nil then
            if type(options) == 'string' then
                local t = type(element)
                if t ~= options then
                    local str = tostring(element)
                    error(fmt("config element '%s' should have type '%s' but is '%s', %s"), k, options, t, str)
                end
            elseif not contains(options, element) then
                local possible = arrayToString(options)
                error(fmt("config element '%s' should be one of: %s.\ngot: %q", k, possible, tostring(element)))
            end
        end
    end

    return config
end

local function applyDefaults(config, defaults)
    if defaults then
        for k, v in pairs(defaults) do
            if config[k] == nil then
                config[k] = v
            end
        end
    end
end

---------------------------------------------------------------------------
function export.verify(def)
    local spec = assert(def.spec, 'args.verify() requires a "spec" element')
    local config = def.config
    local defaults = def.defaults
    local userDefaults = def.userDefaults
    local ignoreUnrecognized = def.ignoreUnrecognized

    config = convertIfArgs(config, spec, ignoreUnrecognized)

    -- Apply user defaults first, to override system defaults
    applyDefaults(config, userDefaults)
    applyDefaults(config, defaults)

    return verifyWithSpec(config, spec)
end

---------------------------------------------------------------------------
function export.describe(spec, defaults, uncolored, helpTitle)
    local color = require('loon.color')[uncolored and "no" or "ansi"]
    local ordered = {}

    for k, v in pairs(spec) do
        table.insert(ordered, {k, v})
    end

    table.sort(ordered, function(a, b) return a[1] < b[1] end)

    iowrite(helpTitle or 'A Lua test suite written with Loon.', '\n\n')
    local spaced = {}

    for _, elem in ipairs(ordered) do
        local name = elem[1]
        local nameS = color.green('--' .. name)
        local descS = elem[2].desc or 'no description'

        local default = defaults[elem[1]]
        local options = assert(elem[2].options)
        local boolean = ofType(options, 'boolean')
        local freeform = type(options) == 'string'
        local defaultS, requiredS, optionsS = '', elem[2].required and '(required)' or ''

        if boolean then
            optionsS = fmt('[%s]', color.grey('flag'))
            defaultS = fmt('(default: %s)', color.yellow(default == true and 'on' or 'off'))
        elseif freeform then
            optionsS = fmt('[%s]', color.orange(options))
        else
            optionsS = fmt('[%s]', arrayToString(options, '|', color.blue))
            defaultS = fmt('(default: %s)', color.yellow(default))
        end

        table.insert(spaced, {nameS, optionsS, descS, defaultS, requiredS, '\n'})
    end

    local max = 0

    for _, elem in ipairs(spaced) do
        max = math.max(max, #elem[1] + 1)
    end

    for _, elem in ipairs(spaced) do
        elem[1] = elem[1] .. string.rep(' ', max - #elem[1])
        iowrite(table.concat(elem, ' '))
    end

    iowrite(color.grey("\nFor strings, numbers or choices, supply the argument like this:"))
    iowrite("\n  --name argument / --name=argument\n")

    iowrite(color.grey("\nFor flags, no argument is required to turn the option on."))
    iowrite(color.grey("\nTo turn it off, supply an option of 'false':"))
    iowrite("\n  --name false / --name=false\n")
end

return export
