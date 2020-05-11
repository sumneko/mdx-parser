local l = require 'lpeglabel'

local tonumber  = tonumber
local type      = type
local assert    = assert
local tostring  = tostring
local error     = error
local tableSort = table.sort
local ipairs    = ipairs
local osClock   = os.clock
local print     = print
local select    = select

_ENV = nil

local function State(key, ...)
    local state = { key = key }
    local num = select('#', ...)
    if num >= 1 then
        state.value = select(num, ...)
    end
    if num >= 2 then
        state.attribute = {}
        for i = 1, num - 1 do
            state.attribute[i] = select(i, ...)
        end
    end

    return state
end

local mdlParser = l.P {
    l.Ct((l.V'Token' + #l.P(1) * l.T'Unknown')^0),
    Token   = l.V'Space' + l.V'State' + l.V'Value',
    Space   = l.S' \t\r\n'^1 + l.V'Comment',
    Empty   = l.V'Space'^-1,
    State   = l.V'Word' * l.V'Empty' * ((l.V'String' + l.V'Number') * l.V'Empty')^0 * l.V'Value'^-1 / State,
    Value   = l.V'Word' + l.V'String' + l.V'Table' + l.V'NumPair' + l.V'Number',
    Seg     = l.P',',
    Comment = l.P'//' * (1 - l.S'\r\n')^0,
    Number  = l.C(l.P'-'^-1 * l.R'09'^1 * l.V'Decimal'^-1) / tonumber,
    NumPair = l.Ct(l.V'Number' * l.V'Space'^-1 * l.P':' * l.V'Space'^-1 * (l.V'Number' + l.V'Table')),
    Decimal = l.P'.' * l.R'09'^0,
    String  = l.P'"' * l.C((1 - l.P'"')^0) * l.P'"',
    Char    = l.R('az', 'AZ', '09', '__'),
    Word    = l.C(l.R('az', 'AZ', '__') * l.R('az', 'AZ', '09', '__')^0),
    Table   = l.Ct(l.P'{' * (l.V'Token' * l.V'Seg'^-1 + (l.T'Unknown' - l.P'}'))^0 * l.P'}'),
}

local function encode(model)
end

local function decode(buf)
    local clock = osClock()
    local tokens, err, pos = mdlParser:match(buf)
    assert(tokens, 'Parse mdl failed at:' .. tostring(pos))
    print(osClock() - clock)
end

return {
    encode = encode,
    decode = decode,
}
