local converter = require 'converter'

local inputs = {
    [[D:\Github\mdx-parser\test\mdl\druidofthetalon.mdl]],
}
local output = [[D:\Github\DzMapCoreTest\resource]]
local war3path = [[E:\Warcraft III]]

local session = converter()
session:openWar3(war3path)
for _, input in ipairs(inputs) do
    session:convert(input, output, 800, 'model/' .. input:match '([^/\\]+)%.')
end

print('ok')
