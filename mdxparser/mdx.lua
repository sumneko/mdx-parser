local hex = include 'hex.lua'

_ENV = nil

local mdxDefine = hex.define {
    
}

local function encode(model)
end

local function decode(buf)
end

return {
    encode = encode,
    decode = decode,
}
