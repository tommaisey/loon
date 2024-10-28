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

            if ofType(spec, 'boolean') then
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
            elseif ofType(spec, 'number') then
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

        if element ~= nil then
            if type(spec) == 'string' then
                local t = type(element)
                if t ~= spec then
                    local str = tostring(element)
                    error(fmt("config element '%s' should have type '%s' but is '%s', %s"), k, spec, t, str)
                end
            elseif not contains(spec, element) then
                local possible = arrayToString(spec)
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
function export.verify(config, spec, defaults, userDefaults, ignoreUnrecognized)
    assert(spec, 'args spec is required')
    config = convertIfArgs(config, spec, ignoreUnrecognized)

    -- Apply user defaults first, to override system defaults
    applyDefaults(config, userDefaults)
    applyDefaults(config, defaults)

    return verifyWithSpec(config, spec)
end

return export
