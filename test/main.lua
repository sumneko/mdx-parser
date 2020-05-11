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
    assert(buf == newBuf)
    if not util.equal(model, newModel) then
        fsu.saveFile(tempDir / path:stem() .. '_old.lua', util.dump(model))
        fsu.saveFile(tempDir / path:stem() .. '_new.lua', util.dump(newModel))
        error('MDL test failed!')
    end
end

-- 测试 mdx 转 mdl
--for path in fsu.scan(mdlDir) do
--    local mdxPath = mdxDir / (path:stem() .. '.mdx')
--    local mdlBuf = fsu.loadFile(mdlDir / path)
--    local mdxBuf = fsu.loadFile(mdxPath)
--    local mdlModel = parser.mdl.decode(mdlBuf)
--    local mdxModel = parser.mdl.encode(mdxBuf)
--    if not util.equal(mdlModel, mdxModel) then
--        fsu.saveFile(tempDir / path:stem() .. '_mdl.lua', util.dump(mdlModel))
--        fsu.saveFile(tempDir / path:stem() .. '_mdx.lua', util.dump(mdxModel))
--        error('MDL test failed!')
--    end
--end

print('Test OK!')
