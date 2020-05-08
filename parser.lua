local l = require 'lpeglabel'

local tonumber = tonumber
local type     = type
local assert   = assert
local tostring = tostring
local error    = error

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
            t[#t+1] = token
            index = index + 1
        end
    end
    return t, index + 1
end

local function parseMDLTokensValue(tokens, index)
    index = index + 1
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

local function parseMDLTokensStruct(tokens, index)
    local struct = {}
    index = index + 1
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
        else
            struct[token], index = parseMDLTokensValue(tokens, index)
        end
    end
    return struct, index + 1
end

local function parseMDLTokensArray(tokens, index, key)
    local array = {}
    index = index + 1
    local count = tokens[index]
    index = index + 2
    local max = #tokens
    while index <= max do
        local token = tokens[index]
        if token == '}' then
            break
        else
            assert(token == key)
            array[#array+1], index = parseMDLTokensStruct(tokens, index)
        end
    end
    assert(count == #array)
    return array, index + 1
end

local function parseMDLTokensVersion(tokens, index)
    return tokens[index + 3], index + 4
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
            model[token], index = parseMDLTokensVersion(tokens, index)
        elseif token == 'Model' then
            model[token], index = parseMDLTokensStruct(tokens, index)
        elseif token == 'Sequences' then
            model[token], index = parseMDLTokensArray(tokens, index, 'Anim')
        elseif token == 'Textures' then
            model[token], index = parseMDLTokensArray(tokens, index, 'Bitmap')
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
