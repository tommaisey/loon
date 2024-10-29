local ansi = {}

function ansi.foreground(code, bit8)
    if bit8 then
        return function(text)
            return "\27[38;5;" .. tostring(code) .. "m" .. tostring(text) .. "\27[0m"
        end
    else
        return function(text)
            return "\27[" .. tostring(code) .. "m" .. tostring(text) .. "\27[0m"
        end
    end
end

ansi.red = ansi.foreground(31)
ansi.green = ansi.foreground(32)
ansi.yellow = ansi.foreground(33)
ansi.blue = ansi.foreground(34)
ansi.magenta = ansi.foreground(35)
ansi.cyan = ansi.foreground(36)
ansi.grey = ansi.foreground(37)
ansi.orange = ansi.foreground(214, '8bit')

local colored = {
    fail = ansi.red,
    pass = ansi.green,
    file = ansi.cyan,
    line = ansi.cyan,
    suite = ansi.blue,
    msg = ansi.orange,
    warn = ansi.yellow,
    value = ansi.magenta,
}

local uncolored = {}
for key in pairs(colored) do
    uncolored[key] = tostring
end
for key in pairs(ansi) do
    uncolored[key] = tostring
end

return {yes = colored, no = uncolored, ansi = ansi}
