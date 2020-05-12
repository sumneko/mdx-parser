local type         = type
local error        = error
local ipairs       = ipairs
local pairs        = pairs
local assert       = assert
local print        = print

_ENV = nil

local function deepCopy(source, target)
    local mark = {}
    local function copy(a, b)
        if type(a) ~= 'table' then
            return a
        end
        if mark[a] then
            return mark[a]
        end
        if not b then
            b = {}
        end
        mark[a] = b
        for k, v in pairs(a) do
            b[copy(k)] = copy(v)
        end
        return b
    end
    return copy(source, target)
end

local function tableMultiRemove(t, index)
    local mark = {}
    for i = 1, #index do
        local v = index[i]
        mark[v] = true
    end
    local offset = 0
    local me = 1
    local len = #t
    while true do
        local it = me + offset
        if it > len then
            for i = me, len do
                t[i] = nil
            end
            break
        end
        if mark[it] then
            offset = offset + 1
        else
            if me ~= it then
                t[me] = t[it]
            end
            me = me + 1
        end
    end
end

local function findState(chunk, key, all)
    if all then
        local list = {}
        for _, state in ipairs(chunk) do
            if state.key == key then
                list[#list+1] = state
            end
        end
        if #list == 0 then
            return nil
        else
            return list
        end
    else
        for _, state in ipairs(chunk) do
            if state.key == key then
                return state
            end
        end
        return nil
    end
end

local function addState(chunk, key, value, attribute, static)
    chunk[#chunk+1] = {
        key       = key,
        value     = value,
        attribute = attribute,
        static    = static,
    }
end

local function getValue(model, keys)
    local chunk = model
    for i = 1, #keys do
        local key = keys[i]
        local state = findState(chunk, key)
        if not state then
            return nil
        end
        chunk = state.value
    end
    return chunk
end

local function setValue(model, keys, value)
    local chunks = { model }
    for i = 1, #keys - 1 do
        local newChunks = {}
        for _, chunk in ipairs(chunks) do
            local key = keys[i]
            local states = findState(chunk, key, true)
            if states then
                for _, state in ipairs(states) do
                    newChunks[#newChunks+1] = state.value
                end
            end
        end
        chunks = newChunks
    end
    local key = keys[#keys]
    for _, chunk in ipairs(chunks) do
        local tstates = findState(chunk, key, true)
        if tstates then
            for _, tstate in ipairs(tstates) do
                local oldValue = tstate.value
                local newValue
                if type(value) == 'function' then
                    newValue = value(oldValue)
                else
                    newValue = value
                end
                tstate.value = newValue
            end
        else
            local newValue
            if type(value) == 'function' then
                newValue = value(nil)
            else
                newValue = value
            end
            addState(chunk, key, newValue)
        end
    end
end

local function setAttribute(model, keys, attribute)
    local chunks = { model }
    for i = 1, #keys - 1 do
        local newChunks = {}
        for _, chunk in ipairs(chunks) do
            local key = keys[i]
            local states = findState(chunk, key, true)
            if states then
                for _, state in ipairs(states) do
                    newChunks[#newChunks+1] = state.value
                end
            end
        end
        chunks = newChunks
    end
    local key = keys[#keys]
    for _, chunk in ipairs(chunks) do
        local tstates = findState(chunk, key, true)
        if tstates then
            for _, tstate in ipairs(tstates) do
                local oldAttr = tstate.attribute
                local newAttr
                if type(attribute) == 'function' then
                    newAttr = attribute(oldAttr)
                else
                    newAttr = attribute
                end
                tstate.attribute = newAttr
            end
        else
            local newAttr
            if type(attribute) == 'function' then
                newAttr = attribute(nil)
            else
                newAttr = attribute
            end
            addState(chunk, key, nil, newAttr)
        end
    end
end

local function removeState(model, keys)
    local chunks = { model }
    for i = 1, #keys - 1 do
        local newChunks = {}
        for _, chunk in ipairs(chunks) do
            local key = keys[i]
            local states = findState(chunk, key, true)
            if states then
                for _, state in ipairs(states) do
                    newChunks[#newChunks+1] = state.value
                end
            end
        end
        chunks = newChunks
    end
    local key = keys[#keys]
    for _, chunk in ipairs(chunks) do
        local indexes = {}
        for i = 1, #chunk do
            if chunk[i].key == key then
                indexes[#indexes+1] = i
            end
        end
        tableMultiRemove(chunk, indexes)
    end
end

local function convertVersion800(model)
    local version = getValue(model, {'Version', 'FormatVersion'})
    assert(version)
    if version == 800 then
        return model
    end
    local newModel = deepCopy(model)
    setValue(newModel, {'Version', 'FormatVersion'}, 800)
    setValue(newModel, {'Textures', 'Bitmap', 'Image'}, function (filename)
        return filename:gsub('%.tif"$', '.blp"'):gsub('/', '\\')
    end)
    removeState(newModel, {'Model', 'NumFaceFX'})
    removeState(newModel, {'Materials', 'Material', 'Shader'})
    removeState(newModel, {'Materials', 'Material', 'TwoSided'})
    removeState(newModel, {'Materials', 'Material', 'Layer', 'EmissiveGain'})
    removeState(newModel, {'Geoset', 'Tangents'})
    removeState(newModel, {'Geoset', 'SkinWeights'})
    removeState(newModel, {'Geoset', 'LevelOfDetail'})
    removeState(newModel, {'Geoset', 'Name'})
    removeState(newModel, {'FaceFX'})
    removeState(newModel, {'BindPose'})
    local first
    setValue(newModel, {'Geoset'}, function (obj)
        if not first then
            first = obj
        end
    end)
    removeState(newModel, {'Geoset'})
    setValue(newModel, {'Geoset', 'Vertices'}, function (obj)
    end)
    return newModel
end

local function convertVersion(model, newVersion)
    if newVersion == 800 then
        return convertVersion800(model)
    else
        error('Unsupport target version!')
    end
end

return {
    getValue       = getValue,
    setValue       = setValue,
    removeState    = removeState,
    convertVersion = convertVersion,
}
