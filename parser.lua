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
    else
        value = token
        index = index + 1
    end
    return value, index
end

local function parseMDLTokensModel(tokens, index)
    local model = {}
    index = index + 1
    model.name = tokens[index]
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
        else
            model[token], index = parseMDLTokensValue(tokens, index)
        end
    end
    return model, index + 1
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
            index = index + 3
            model.version = tokens[index]
            index = index + 1
        elseif token == 'Model' then
            model.Model, index = parseMDLTokensModel(tokens, index)
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
