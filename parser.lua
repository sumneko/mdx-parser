--- 解析 `mdx` 为模型数据
local function mdxDecode(buf)
end

--- 将模型数据转换为 `mdx` 格式
local function mdxEncode(model)
end

--- 解析 `mdl` 为模型数据
local function mdlDecode(buf)
    
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
