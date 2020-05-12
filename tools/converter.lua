local fs     = require 'bee.filesystem'
local war3   = require 'war3'
local parser = require 'mdxparser'
local fsu    = require 'fs-utility'
local sp     = require 'bee.subprocess'

local mt = {}
mt.__index = mt

function mt:readFile(filename, input)
    local path = fs.path(filename)
    local stem = (path:parent_path() / path:stem()):string()
    local nativeDir = fs.path(input) / 
    for _, ext in ipairs {'.dds', '.blp', '.tga'} do
        local buf = fsu.loadFile(nativeDir / (stem .. ext))
        if buf then
            return buf, ext
        end
    end
    if self.war3 then
        for _, where in ipairs {'_hd.w3mod:', ''} do
            for _, ext in ipairs {'.dds', '.blp', '.tga'} do
                local buf = self.war3:readfile(where .. stem .. ext)
                if buf then
                    return buf, ext
                end
            end
        end
    end
    return nil
end

function mt:fixImage(newModel, input, output, prefix)
    fs.create_directories(fs.path 'temp')
    local converted = {}
    local id = 0
    parser.model.setValue(newModel, {'Textures', 'Bitmap', 'Image'}, function (filename)
        local image = fs.path(filename:sub(2, -2))
        if converted[image] then
            return converted[image]
        end
        local buf, ext = self:readFile()
        if not buf then
            converted[image] = filename
            return converted[image]
        end
        local stem
        if prefix then
            id = id + 1
            stem = (fs.path(prefix) / tonumber(id)):string():gsub('/', '\\')
        else
            stem = fs.path(image):stem():string():gsub('/', '\\')
        end
        if ext == '.dds' then
            local tempPath = fs.path 'temp' / 'image.dds'
            fsu.saveFile(tempPath, buf)
            local p = sp.spawn {
                fs.path 'tools' / 'bin' / 'readdxt.exe',
                tempPath,
            }
            p:wait()
            local newImage = stem .. ext
            fs.copy_file(tempPath:parent_path() / (tempPath:stem() .. '00.tga'), fs.path(output) / newImage, true)
            converted[image] = '"' .. newImage .. '"'
        else
            local newImage = stem .. ext
            fsu.saveFile(fs.path(output) / newImage, buf)
            converted[image] = '"' .. newImage .. '"'
        end
        return converted[image]
    end)
end

function mt:openWar3(war3path)
    self.war3 = war3()
    self.war3:open(fs.path(war3path))
end

function mt:convert(input, output, version, prefix)
    local buf = fsu.loadFile(fs.path(input))
    if not buf then
        error('Cannot open file:' .. tostring(input))
    end
    local model = parser.mdl.decode(buf)
    local newModel = parser.model.convertVersion(model, version)
    self:fixImage(newModel, input, output, prefix)
end

return function (war3path)
    return setmetatable({}, mt)
end
