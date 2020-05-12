local assert       = assert
local setmetatable = setmetatable
local debugGetInfo = debug.getinfo
local ioOpen       = io.open
local load         = load

local env = setmetatable({}, { __index = _ENV })

_ENV = nil

local loaded = {}
local function include(path)
    local myPath = debugGetInfo(2, 'S').source
    if myPath:sub(1, 1) == '@' then
        myPath = myPath:sub(2)
    end
    local newPath = myPath:gsub('[^/\\]+$', '') .. path
    if loaded[newPath] then
        return loaded[newPath]
    end
    local f = assert(ioOpen(newPath, 'r'))
    local buf = f:read 'a'
    f:close()
    local init = assert(load(buf, '@' .. newPath, 'bt', env))
    local res = init(newPath, newPath)
    loaded[newPath] = res or true
    return res
end

env.include = include

return {
    mdl            = include 'mdl.lua',
    mdx            = include 'mdx.lua',
    model          = include 'model.lua',
}
