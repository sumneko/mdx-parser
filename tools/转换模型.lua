local converter = require 'tools.converter'

local inputs = {
    [[D:\Github\mdx-parser\test\mdl\druidofthetalon.mdl]],
}
local output = [[D:\Github\DzMapCoreTest\resource\model]]
local war3path = [[E:\Warcraft III]]

local session = converter(war3path)
for _, input in ipairs(inputs) do
    session:convert(input, output, 800, 'model')
end

print('ok')
