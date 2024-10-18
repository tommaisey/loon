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

local function arrayToString(array)
    local strs = {}
    for _, value in ipairs(array) do
        insert(strs, tostring(value))
    end
    return table.concat(strs, ', ')
end

local function allType(array, typeString)
    for _, val in pairs(array) do
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
        end

        if type(element) == 'string' and element:find('[Llua]') then
            return true
        end

        idx = idx - 1
    end
end

local function convertIfArgs(config, specs)
    if config == nil then
        return {}
    end

    if not isArgsList(config) then
        return config
    end

    local convertedConfig = {}
    local idx = 1

    while(true) do
        local item = config[idx]
        if item == nil then break end

        local name = item:match('^%-*(.+)$')
        local valueAfterEquals

        if name == nil then
            error("malformed argument: " .. name)
        end

        if name:find('=') then
            local name2, value2 = name:match('([^=]+)=([^=]+)')

            if not name2 or not value2 or #name2 == 0 or #value2 == 0 then
                error("malformed argument with '=' syntax: " .. name)
            end

            name, valueAfterEquals = name2, value2
        end

        local spec = specs[name]

        if spec == nil then
            error("unrecognized argument: " .. name)
        end

        idx = idx + 1
        local value

        if allType(spec, 'boolean') then
            value = true
        elseif valueAfterEquals then
            value = valueAfterEquals:match('["\']?([^"\']+)')
        else
            value = config[idx]
            idx = idx + 1
        end

        if allType(spec, 'number') then
            value = assert(tonumber(value), "couldn't convert argument to a number: " .. value)
        end

        convertedConfig[name] = value
    end

    return convertedConfig
end

local function verifyWithSpec(config, specs)
    for k, spec in pairs(specs) do
        local element = config[k]

        if element ~= nil then
            if not contains(spec, element) then
                local possible = arrayToString(spec)
                error(fmt("config element '%s' should be one of: %s.\ngot: %q", k, possible, tostring(element)))
            end
        end
    end

    return config
end

function export.verify(config, spec, defaults)
    config = convertIfArgs(config, spec)

    if defaults then
        for k, v in pairs(defaults) do
            if config[k] == nil then
                config[k] = v
            end
        end
    end

    return verifyWithSpec(config, spec)
end

return export