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
for path in fsu.scan(mdxDir) do
    --local buf1 = fsu.loadFile(mdxDir / path)
    local buf2 = fsu.loadFile(mdlDir / (path:stem() .. '.mdl'))
    --local model1 = parser.mdx.decode(buf1)
    local model2 = parser.mdl.decode(buf2)
    --assert(util.equal(model1, model2))
    local mdlBuf = parser.mdl.encode(model2)
    fsu.saveFile(tempDir / (path:stem() .. '.mdl'), mdlBuf)
end
print(1)
