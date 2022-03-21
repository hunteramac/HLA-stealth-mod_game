--example test
--need to be able to call functions from another file in tests
-- need tests to default run from lua5.1(in engine lua version)
-- currently runs from Lua.5.3

require 'busted.runner'()
package.path = "./?.lua;" .. package.path
local some_stuff = require("some_stuff")


describe("a test", function()
    --arrange
    a = 1
    --act
    a = some_stuff.add_one(a)
    --assert
    assert.is_true(a == 2)
end)

describe("dt test", function()
    --arrange
    dt_stuff = {}
    dt_stuff["view1"] = false
    dt_stuff["view2"] = false
    dt_stuff["view3"] = true
    --act
    a = some_stuff.respond_to_dt(dt_stuff)
    --assert
    assert.is_true(a == 2)
end)