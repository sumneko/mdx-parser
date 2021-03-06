local l = require 'lpeglabel'

local tonumber     = tonumber
local type         = type
local assert       = assert
local tostring     = tostring
local ipairs       = ipairs
local select       = select
local tableConcat  = table.concat
local setmetatable = setmetatable

_ENV = nil

local Tab = setmetatable({}, { __index = function (self, n)
    self[n] = ('\t'):rep(n)
    return self[n]
end })

local function State(static, key, ...)
    local state = {
        key    = key,
        static = static,
    }
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
    Token   = l.V'Space' + l.V'State',
    Space   = l.S' \t\r\n'^1 + l.V'Comment',
    Empty   = l.V'Space'^0,
    Attr    = l.V'Empty' * (l.V'String' + l.V'Number') * l.V'Empty',
    Static  = l.V'Empty' * (l.C(l.P'static') + l.Cc(nil)) * l.V'Empty',
    Key     = l.V'Empty' * l.V'Word' * l.V'Empty',
    State   = l.V'Static' * l.V'Key' * l.V'Attr'^1 * l.V'Struct' / State
            + l.V'Static' * l.V'Key' * (l.V'Value' + l.V'Struct')^-1 / State
            + l.V'Static' * l.V'Number' * l.V'Empty' * l.C(l.P':') * l.V'Empty' * l.V'Value' / State,
    Value   = l.V'Word' + l.V'String' + l.V'Array' + l.V'Number',
    Comma   = l.V'Empty' * l.P',' * l.V'Empty',
    Comment = l.P'//' * (1 - l.S'\r\n')^0,
    Number  = l.C(l.P'-'^-1 * l.R'09'^1 * l.V'Decimal'^-1 * l.V'Expon'^-1),
    Decimal = l.P'.' * l.R'09'^0,
    Expon   = l.S'Ee' * l.P'-'^-1 * l.R'09'^1,
    String  = l.C(l.P'"' * (1 - l.P'"')^0 * l.P'"'),
    Word    = l.C(l.R('az', 'AZ', '__') * l.R('az', 'AZ', '09', '__')^0),
    Afield  = l.V'Empty' * l.V'Value' * l.V'Empty',
    Array   = l.Ct(l.Cg(l.Cc'Array', 'type') * l.P'{'
                * (l.V'Afield' * l.V'Comma')^0 * l.V'Afield'^-1
            * l.V'Empty' * l.P'}'),
    Sfield  = l.V'Empty' * (l.V'State' + l.V'Value') * l.V'Empty',
    Struct  = l.Ct(l.Cg(l.Cc'Struct', 'type') * l.P'{'
                * (l.V'Sfield' * l.V'Comma'^-1 + #(1 - l.P'}') * l.T'Unknown')^0
            * l.V'Empty' * l.P'}'),
}

local function encodeAttribute(buf, attributes)
    for i = 1, #attributes do
        if attributes[i] ~= ':' then
            buf[#buf+1] = ' '
        end
            buf[#buf+1] = attributes[i]
    end
end

local NeedCommaKey = {
    VertexGroup  = false,
    Triangles    = false,
    SkinWeights  = false,
    SegmentColor = true,
    Anim         = false,
    Particle     = false,
    Target       = false,
}

local encodeValue
local function encodeState(buf, pkey, state, tab)
    local key = state.key
    local isStruct
    buf[#buf+1] = Tab[tab]
    if key then
        if state.static then
            buf[#buf+1] = 'static '
        end
        buf[#buf+1] = key
        if state.attribute then
            encodeAttribute(buf, state.attribute)
        end
        if state.value then
            buf[#buf+1] = ' '
            encodeValue(buf, key, state.value, tab)
            if type(state.value) == 'table' and state.value.type == 'Struct' then
                isStruct = true
            end
        end
    else
        encodeValue(buf, pkey, state, tab)
    end
    if NeedCommaKey[key] == nil then
        if isStruct then
            buf[#buf+1] = '\r\n'
        else
            buf[#buf+1] = ',\r\n'
        end
    else
        if NeedCommaKey[key] then
            buf[#buf+1] = ',\r\n'
        else
            buf[#buf+1] = '\r\n'
        end
    end
end

local function encodeTable(buf, key, value, tab)
    local mode = value.type
    if mode == 'Struct' then
        buf[#buf+1] = '{\r\n'
        for i = 1, #value do
            encodeState(buf, key, value[i], tab + 1)
        end
        buf[#buf+1] = Tab[tab]
        buf[#buf+1] = '}'
    elseif mode == 'Array' then
        if tonumber(value[1]) then
            if key == 'SkinWeights' then
                buf[#buf+1] = '{\r\n'
                for i = 1, #value do
                    if i % 8 == 1 then
                        buf[#buf+1] = Tab[tab + 1]
                    end
                    encodeValue(buf, key, value[i], tab + 1)
                    if i % 8 == 0 then
                        buf[#buf+1] = ', \r\n'
                    else
                        buf[#buf+1] = ', '
                    end
                end
                buf[#buf+1] = Tab[tab]
                buf[#buf+1] = '}'
            elseif key == 'Alpha'
            or     key == 'ParticleScaling'
            or     key == 'LifeSpanUVAnim'
            or     key == 'DecayUVAnim'
            or     key == 'TailUVAnim'
            or     key == 'TailDecayUVAnim' then
                buf[#buf+1] = '{'
                for i = 1, #value do
                    if i > 1 then
                        buf[#buf+1] = ' '
                    end
                    encodeValue(buf, key, value[i], tab)
                    if i < #value then
                        buf[#buf+1] = ','
                    end
                end
                buf[#buf+1] = '}'
            elseif key == 'Matrices' then
                buf[#buf+1] = '{'
                for i = 1, #value do
                    if #value >= 10 then
                        encodeValue(buf, key, value[i], tab)
                        buf[#buf] = ('% 13s'):format(buf[#buf])
                    else
                        buf[#buf+1] = ' '
                        encodeValue(buf, key, value[i], tab)
                    end
                    if i < #value then
                        buf[#buf+1] = ','
                    end
                end
                buf[#buf+1] = ' }'
            elseif key == 'VertexGroup' then
                buf[#buf+1] = '{\r\n'
                for i = 1, #value do
                    buf[#buf+1] = Tab[tab + 1]
                    encodeValue(buf, key, value[i], tab + 1)
                    buf[#buf+1] = ',\r\n'
                end
                buf[#buf+1] = Tab[tab]
                buf[#buf+1] = '}'
            else
                buf[#buf+1] = '{'
                for i = 1, #value do
                    buf[#buf+1] = ' '
                    encodeValue(buf, key, value[i], tab)
                    if i < #value then
                        buf[#buf+1] = ','
                    end
                end
                buf[#buf+1] = ' }'
            end
        else
            buf[#buf+1] = '{\r\n'
            for i = 1, #value do
                buf[#buf+1] = Tab[tab + 1]
                encodeValue(buf, key, value[i], tab + 1)
                buf[#buf+1] = ',\r\n'
            end
            buf[#buf+1] = Tab[tab]
            buf[#buf+1] = '}'
        end
    end
end

function encodeValue(buf, key, value, tab)
    if type(value) == 'table' then
        encodeTable(buf, key, value, tab)
    else
        buf[#buf+1] = value
    end
end

local function encode(model)
    local buf = {}
    for _, chunk in ipairs(model) do
        encodeState(buf, 'ROOT', chunk, 0)
    end
    return tableConcat(buf)
end

local function decode(buf)
    local model, err, pos = mdlParser:match(buf)
    assert(model, 'Parse mdl failed at:' .. tostring(pos))
    return model
end

return {
    encode = encode,
    decode = decode,
}
