local l = require 'lpeglabel'

local tonumber  = tonumber
local type      = type
local assert    = assert
local tostring  = tostring
local error     = error
local tableSort = table.sort
local ipairs    = ipairs

_ENV = nil

local mdlParser = l.P {
    l.Ct(l.V'Token'^0),
    Token   = l.V'Space' + l.V'Number' / tonumber + l.V'String' + l.V'Symbol' + l.V'Word' + l.P(1) * l.T'Unknown',
    Space   = l.S' \t\r\n'^1 + l.V'Comment',
    Comment = l.P'//' * (1 - l.S'\r\n')^0,
    Number  = l.C(l.P'-'^-1 * l.R'09'^1 * l.V'Decimal'^-1),
    Decimal = l.P'.' * l.R'09'^0,
    String  = l.P'"' * l.C((1 - l.P'"')^0) * l.P'"',
    Symbol  = l.C(l.S'{},:'),
    Char    = l.R('az', 'AZ', '09') + l.P'_',
    Word    = l.C(l.V'Char'^1),
}

local parseMDLTokensValue
local function parseMDLTokensSimpleTable(tokens, index)
    local t = {}
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == '}' then
            break
        elseif token == ',' then
            index = index + 1
        else
            t[#t+1], index = parseMDLTokensValue(tokens, index)
        end
    end
    return t, index + 1
end

function parseMDLTokensValue(tokens, index)
    local value
    local token = tokens[index]
    if token == '{' then
        value, index = parseMDLTokensSimpleTable(tokens, index)
    elseif token == '}'
    or     token == ',' then
        value = true
    else
        value = token
        index = index + 1
    end
    return value, index
end

local function parseMDLTokensValueList(tokens, index)
    local count = tokens[index]
    index = index + 2
    local list = {}
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        else
            list[#list+1], index = parseMDLTokensValue(tokens, index)
        end
    end
    assert(count == #list)
    return list, index + 1
end

local function parseMDLTokensAnimationData(tokens, index)
    local time = tokens[index]
    index = index + 1
    assert(tokens[index] == ':')
    index = index + 1
    local data = {}
    data.time = time
    data.value, index = parseMDLTokensValue(tokens, index)
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ','
        or token == '}' then
            break
        else
            data[token], index = parseMDLTokensValue(tokens, index)
        end
    end
    return data, index
end

local function parseMDLTokensAnimation(tokens, index)
    local data = {}
    local list = {}
    data.list = list
    local count = tokens[index]
    index = index + 2
    data.type = tokens[index]
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'GlobalSeqId' then
            data[token], index = parseMDLTokensValue(tokens, index + 1)
        else
            list[#list+1], index = parseMDLTokensAnimationData(tokens, index)
        end
    end
    assert(count == #list)
    tableSort(list, function (a, b)
        if a.time == b.time then
            return a.value < b.value
        end
        return a.time < b.time
    end)
    return data, index + 1
end

local function parseMDLTokensLayer(tokens, index)
    local layer = {}
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        assert(token ~= '{')
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'Alpha'
        or     token == 'EmissiveGain' then
            layer[token], index = parseMDLTokensAnimation(tokens, index + 1)
        elseif token == 'static' then
            index = index + 1
        else
            layer[token], index = parseMDLTokensValue(tokens, index)
        end
    end
    return layer, index + 1
end

local function parseMDLTokensStruct(tokens, index)
    local struct = {}
    local token = tokens[index]
    if token ~= '{' then
        struct.name = token
        index = index + 1
    end
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == 'static' then
            index = index + 1
        elseif token == '}' then
            break
        else
            struct[token], index = parseMDLTokensValue(tokens, index + 1)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensMaterial(tokens, index)
    local struct = {}
    local layers = {}
    struct.layers = layers
    local token = tokens[index]
    if token ~= '{' then
        struct.name = token
        index = index + 1
    end
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'Layer' then
            layers[#layers+1], index = parseMDLTokensLayer(tokens, index + 1)
        else
            struct[token], index = parseMDLTokensValue(tokens, index)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensArray(tokens, index, key, callback)
    local array = {}
    local token = tokens[index]
    local count
    if type(token) == 'number' then
        count = token
        index = index + 1
    end
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == '}' then
            break
        elseif token == ',' then
            index = index + 1
        else
            assert(token == key)
            array[#array+1], index = callback(tokens, index + 1)
        end
    end
    if count then
        assert(count == #array)
    end
    return array, index + 1
end

local function parseMDLTokensGroups(tokens, index)
    local count = tokens[index]
    index = index + 1
    local nums = tokens[index]
    local sum = 0
    index = index + 2
    local array = {}
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == '}' then
            break
        elseif token == ',' then
            index = index + 1
        else
            assert(token == 'Matrices')
            array[#array+1], index = parseMDLTokensValue(tokens, index + 1)
            sum = sum + #array[#array]
        end
    end
    assert(count == #array)
    assert(nums == sum)
    return array, index + 1
end

local function parseMDLTokensFaces(tokens, index)
    local grps = tokens[index]
    index = index + 1
    local cnt = tokens[index]
    index = index + 2
    local data = {}
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'Triangles' then
            data[token], index = parseMDLTokensValue(tokens, index + 1)
            data[token] = data[token][1]
            for i, v in ipairs(data[token]) do
                if grps == 1 then
                    assert(type(v) == 'number')
                    data[token][i] = { v }
                else
                    assert(type(v) == 'table')
                    assert(#v == grps)
                end
            end
            assert(#data[token] * grps == cnt)
        else
            error('Unknown token')
        end
    end

    return data, index + 1
end

local function parseMDLTokensGeoset(tokens, index)
    local struct = {}
    local token = tokens[index]
    if token ~= '{' then
        struct.name = token
        index = index + 1
    end
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'Vertices'
        or     token == 'Normals'
        or     token == 'Tangents' then
            struct[token], index = parseMDLTokensValueList(tokens, index + 1)
        elseif token == 'TVertices' then
            if not struct[token] then
                struct[token] = {}
            end
            struct[token][#struct[token]+1], index = parseMDLTokensValueList(tokens, index + 1)
        elseif token == 'Groups' then
            struct[token], index = parseMDLTokensGroups(tokens, index + 1)
        elseif token == 'Faces' then
            struct[token], index = parseMDLTokensFaces(tokens, index + 1)
        elseif token == 'Anim' then
            if not struct[token] then
                struct[token] = {}
            end
            struct[token][#struct[token]+1], index = parseMDLTokensStruct(tokens, index + 1)
        else
            struct[token], index = parseMDLTokensValue(tokens, index + 1)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensGeosetAnim(tokens, index)
    local struct = {}
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == '}' then
            break
        elseif token == ',' then
            index = index + 1
        elseif token == 'static' then
            index = index + 1
        elseif token == 'Alpha' then
            struct[token], index = parseMDLTokensAnimation(tokens, index + 1)
        else
            struct[token], index = parseMDLTokensValue(tokens, index + 1)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensBone(tokens, index)
    local struct = {}
    local token = tokens[index]
    struct.name = token
    index = index + 1
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'Translation'
        or     token == 'Rotation'
        or     token == 'Scaling'
        or     token == 'Visibility' then
            struct[token], index = parseMDLTokensAnimation(tokens, index + 1)
        else
            struct[token], index = parseMDLTokensValue(tokens, index + 1)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensAttachment(tokens, index)
    local struct = {}
    local token = tokens[index]
    struct.name = token
    index = index + 1
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'Translation'
        or     token == 'Rotation'
        or     token == 'Scaling'
        or     token == 'Visibility' then
            struct[token], index = parseMDLTokensAnimation(tokens, index + 1)
        else
            struct[token], index = parseMDLTokensValue(tokens, index + 1)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensParticleEmitter(tokens, index)
    local struct = {}
    local token = tokens[index]
    struct.name = token
    index = index + 1
    assert(tokens[index] == '{')
    index = index + 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' then
            index = index + 1
        elseif token == 'static' then
            index = index + 1
        elseif token == '}' then
            break
        elseif token == 'Translation'
        or     token == 'Rotation'
        or     token == 'Scaling'
        or     token == 'Visibility' then
            struct[token], index = parseMDLTokensAnimation(tokens, index + 1)
        elseif token == 'SegmentColor' then
            struct[token], index = parseMDLTokensArray(tokens, index + 1, 'Color', parseMDLTokensValue)
        elseif token == 'Particle' then
            struct[token], index = parseMDLTokensStruct(tokens, index + 1)
        else
            struct[token], index = parseMDLTokensValue(tokens, index + 1)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensVersion(tokens, index)
    return tokens[index + 2], index + 3
end

local function parseMDLTokens(tokens)
    local model = {}
    local index = 1
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == ',' or token == '}' then
            index = index + 1
        elseif token == 'Version' then
            model[token], index = parseMDLTokensVersion(tokens, index + 1)
        elseif token == 'Model' then
            model[token], index = parseMDLTokensStruct(tokens, index + 1)
        elseif token == 'Sequences' then
            model[token], index = parseMDLTokensArray(tokens, index + 1, 'Anim'    , parseMDLTokensStruct)
        elseif token == 'Textures' then
            model[token], index = parseMDLTokensArray(tokens, index + 1, 'Bitmap'  , parseMDLTokensStruct)
        elseif token == 'Materials' then
            model[token], index = parseMDLTokensArray(tokens, index + 1, 'Material', parseMDLTokensMaterial)
        elseif token == 'Geoset' then
            if not model[token] then
                model[token] = {}
            end
            model[token][#model[token]+1], index = parseMDLTokensGeoset(tokens, index + 1)
        elseif token == 'GeosetAnim' then
            if not model[token] then
                model[token] = {}
            end
            model[token][#model[token]+1], index = parseMDLTokensGeosetAnim(tokens, index + 1)
        elseif token == 'Bone' then
            if not model[token] then
                model[token] = {}
            end
            model[token][#model[token]+1], index = parseMDLTokensBone(tokens, index + 1)
        elseif token == 'Attachment' then
            if not model[token] then
                model[token] = {}
            end
            model[token][#model[token]+1], index = parseMDLTokensAttachment(tokens, index + 1)
        elseif token == 'PivotPoints' then
            model[token], index = parseMDLTokensValueList(tokens, index + 1)
        elseif token == 'ParticleEmitter' then
            if not model[token] then
                model[token] = {}
            end
            model[token][#model[token]+1], index = parseMDLTokensParticleEmitter(tokens, index + 1)
        elseif token == 'ParticleEmitter2' then
            if not model[token] then
                model[token] = {}
            end
            model[token][#model[token]+1], index = parseMDLTokensParticleEmitter(tokens, index + 1)
        else
            error('Unknown token!')
        end
    end
    return model
end

--- 解析 `mdx` 为模型数据
local function mdxDecode(buf)
end

--- 将模型数据转换为 `mdx` 格式
local function mdxEncode(model)
end

--- 解析 `mdl` 为模型数据
local function mdlDecode(buf)
    local tokens, err, pos = mdlParser:match(buf)
    assert(tokens, 'Parse mdl failed at:' .. tostring(pos))
    local model = parseMDLTokens(tokens)
    return model
end

--- 将模型数据转换为 `mdl` 格式
local function mdlEncode(model)
end

return {
    mdx = {
        decode = mdxDecode,
        encode = mdxEncode,
    },
    mdl = {
        decode = mdlDecode,
        encode = mdlEncode,
    }
}
