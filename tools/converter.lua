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
    for _, ext in ipairs {'.dds', '.blp', '.tga'} do
        local buf = fsu.loadFile(fs.path(input) / (stem .. ext))
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
    if prefix then
        fs.create_directories(fs.path(output) / prefix)
    end
    local converted = {}
    local id = 0
    parser.model.setValue(newModel, {'Textures', 'Bitmap', 'Image'}, function (filename)
        local image = fs.path(filename:sub(2, -2))
        if converted[image] then
            return converted[image]
        end
        local buf, ext = self:readFile(image, input)
        if not buf then
            converted[image] = filename
            return converted[image]
        end
        local stem
        if prefix then
            id = id + 1
            stem = (fs.path(prefix) / tostring(id)):string():gsub('/', '\\')
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
            local newImage = stem .. '.tga'
            fs.copy_file(tempPath:parent_path() / (tempPath:stem() .. '00.tga'), fs.path(output) / newImage, true)
            converted[image] = '"' .. newImage:gsub('%d+%.tga', '1.tga') .. '"'
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
    fs.create_directories(fs.path(output))
    local model = parser.mdl.decode(buf)
    local newModel = parser.model.convertVersion(model, version)
    self:fixImage(newModel, input, output, prefix)
    local newBuf = parser.mdl.encode(newModel)
    if prefix then
        fs.create_directories(fs.path(output) / prefix)
        fsu.saveFile(fs.path(output) / prefix / 'model.mdl', newBuf)
    else
        fsu.saveFile(fs.path(output) / (input:stem():string() .. '.mdl'), newBuf)
    end
end

return function (war3path)
    return setmetatable({}, mt)
end
