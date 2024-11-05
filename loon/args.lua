--------------------------------------------------------------------------------------
-- A library to assist verifying config tables and argument lists.
-- In our model, configuration can be done either way, with
-- loon.run(arg) or loon.run({stuff = true}), so we must
-- convert from argument lists to a config table, then
-- verify the table against a spec.
--
-- The spec is a table of keys to arrays of 'allowed' values.
--------------------------------------------------------------------------------------
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

local function reverseKeyValue(tbl)
    local new = {}
    for key, value in pairs(tbl) do
        new[value] = key
    end
    return new
end

--------------------------------------------------------------------------------------
local booleanConversions = {
    ['true'] = true,
    ['on'] = true,
    ['yes'] = true,
    ['false'] = false,
    ['off'] = false,
    ['no'] = false,
}

local function isArgsList(config)
    local idx = -1

    while(true) do
        local element = config[idx]

        if element == nil then
            return false
        elseif type(element) == 'string' and element:find('^[Llua]') then
            return true
        end

        idx = idx - 1
    end
end

local function consumeArg(name, raw, specs, config, convertedConfig, idx, ignoreUnrecognized)
    local value, isBooleanSwitch

    if name:find('=') then
        name, value = name:match('([^=]+)=([^=]+)')

        if not name or not value or #name == 0 or #value == 0 then
            error(fmt("'%s' is a malformed argument with '=' syntax: no value", raw))
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
            if #name == 1 and raw:match('^%-%-') then
                error(fmt("'%s' is an unrecognized argument. Did you mean -%s?", raw, name))
            else
                error(fmt("'%s' is an unrecognized argument", raw))
            end
        end
    else
        if value then
            value = value:match('["\']?([^"\']+)')
        end

        local options = assert(spec.options, 'spec item lacks options array or type string')

        if ofType(options, 'boolean') then
            if value == nil then
                value = assert(isBooleanSwitch) -- true
            else
                local rawValue = value
                value = booleanConversions[rawValue]

                if value == nil then
                    error(fmt("%s was '%s' but should be 'true/on/yes' or 'false/no/off'", raw, rawValue))
                end
            end
        elseif ofType(options, 'number') then
            value = tonumber(value) or value -- verifyWithSpec will take care of the error message later
        end

        convertedConfig[name] = value
    end

    return idx
end

-- Checks if it's an args list, and if it is, converts it to a
-- standard table with the help of the specs and abbreviations.
local function convertIfArgs(config, specs, abbreviations, ignoreUnrecognized)
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

        local name = item:match('^%-%-(.+)$')

        if name then
            idx = consumeArg(name, item, specs, config, convertedConfig, idx, ignoreUnrecognized)
        else
            local flags = item:match('^%-(.+)$')

            if not flags then
                error(fmt("'%s' cannot be parsed as a flag or option", item))
            end

            if #flags == 1 then
                name = abbreviations[flags] or flags
                idx = consumeArg(name, item, specs, config, convertedConfig, idx, ignoreUnrecognized)
            else
                error('combining single-letter flags is not yet supported!')
            end
        end
    end

    return convertedConfig
end

-- Takes a config (that's been converted to a standard table
-- if it was an args list) and verifies that it meets the spec.
local function verifyWithSpec(config, specs)
    for k, spec in pairs(specs) do
        local element = config[k]
        local options = spec.options

        if element ~= nil then
            if type(options) == 'string' then
                local t = type(element)
                if t ~= options then
                    local str = tostring(element)
                    error(fmt("--%s has type '%s' (%s) but it should be a '%s'", k, t, str, options))
                end
            elseif not contains(options, element) then
                local possible = arrayToString(options)
                error(fmt("--%s was '%s' but should be one of: %s.", k, tostring(element), possible))
            end
        end
    end

    return config
end

-- Applies any defaults if they're missing in the config.
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
    local config = def.config or {}
    local defaults = def.defaults or {}
    local userDefaults = def.userDefaults or {}
    local abbreviations = def.abbreviations or {}
    local ignoreUnrecognized = def.ignoreUnrecognized

    config = convertIfArgs(config, spec, abbreviations, ignoreUnrecognized)

    -- Apply user defaults first, to override system defaults
    applyDefaults(config, userDefaults)
    applyDefaults(config, defaults)

    return verifyWithSpec(config, spec)
end

---------------------------------------------------------------------------
function export.describe(def)
    local spec = assert(def.spec, 'args.describe() requires a "spec" element')
    local defaults = def.defaults or {}
    local abbreviations = def.abbreviations or {}
    local uncolored = def.uncolored
    local helpTitle = def.helpTitle or 'A Lua test suite written with Loon.'

    local color = require('loon.color')[uncolored and "no" or "ansi"]
    local ordered = {}
    local abbreversed = reverseKeyValue(abbreviations) -- key/value swapped

    for k, v in pairs(spec) do
        table.insert(ordered, {k, v})
    end

    table.sort(ordered, function(a, b) return a[1] < b[1] end)

    iowrite(helpTitle, '\n\n')
    local spaced = {}
    local max = 0

    for _, elem in ipairs(ordered) do
        local name = elem[1]
        local abbrev = abbreversed[name]
        local nameS = '--' .. color.orange(name) .. (abbrev and ('|-' .. color.orange(abbrev)) or '')
        local len = 3 + #name + (abbrev and 2 + #abbrev or 0)

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
            optionsS = fmt('[%s]', color.cyan(options))
        else
            optionsS = fmt('[%s]', arrayToString(options, '|', color.green))
            defaultS = fmt('(default: %s)', color.yellow(default))
        end

        max = math.max(max, len)
        table.insert(spaced, {len = len, nameS, optionsS, descS, defaultS, requiredS, '\n'})
    end

    for _, elem in ipairs(spaced) do
        table.insert(elem, 2, string.rep(' ', max - elem.len))
        iowrite(table.concat(elem, ' '))
    end

    iowrite(color.grey("\nFor strings, numbers or choices, supply the argument like this:"))
    iowrite("\n  --name argument / --name=argument\n")

    iowrite(color.grey("\nFor flags, no argument is required to turn the option on."))
    iowrite(color.grey("\nTo turn it off, supply an option of 'false':"))
    iowrite("\n  --name false / --name=false\n")
end

return export
