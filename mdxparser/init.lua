local loaded = {}
local env

local function include(path)
    local myPath = debug.getinfo(2, 'S').source
    if myPath:sub(1, 1) == '@' then
        myPath = myPath:sub(2)
    end
    local newPath = myPath:gsub('[^/\\]+$', '') .. path
    if loaded[newPath] then
        return loaded[newPath]
    end
    local f = assert(io.open(newPath, 'r'))
    local buf = f:read 'a'
    f:close()
    local init = assert(load(buf, '@' .. newPath, 'bt', env))
    local res = init(newPath, newPath)
    loaded[newPath] = res or true
    return res
end

env = setmetatable({
    include = include,
}, { __index = _ENV })

return {
    mdl = include 'mdl.lua',
    mdx = include 'mdx.lua',
}
