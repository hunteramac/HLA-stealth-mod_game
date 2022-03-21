package.path = "./?.lua;" .. package.path
local some_stuff = require("some_stuff")
z = 1
print(z)
z = some_stuff.add_one(z)
print(z)