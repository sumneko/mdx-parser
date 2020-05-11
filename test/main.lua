local fs     = require 'bee.filesystem'
local util   = require 'test.utility'
local fsu    = require 'test.fs-utility'
local parser = require 'mdxparser'
local root   = fs.current_path()
local mdxDir = root / 'test' / 'mdx'
local mdlDir = root / 'test' / 'mdl'
local tempDir = root / 'temp'

fs.create_directories(mdlDir)
fs.create_directories(tempDir)

-- 先测试 mdl 的自我编码解码
for path in fsu.scan(mdlDir) do
    local buf = fsu.loadFile(mdlDir / path)
    local model = parser.mdl.decode(buf)
    local newBuf = parser.mdl.encode(model)
    fsu.saveFile(tempDir / path, newBuf)
    local newModel = parser.mdl.decode(newBuf)
    if not util.equal(model, newModel) then
        fsu.saveFile(tempDir / path:stem() .. '_old.lua',util.dump(model))
        fsu.saveFile(tempDir / path:stem() .. '_new.lua',util.dump(newModel))
        error('MDL test failed!')
    end
end
print('Test OK!')
