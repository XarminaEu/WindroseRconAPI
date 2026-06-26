-- Test for the Json module.

package.path = "WindroseRCON/Scripts/?.lua;" .. package.path
local Json = require("json")

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then print("PASS: " .. name) else print("FAIL: " .. name .. " - " .. tostring(err)) end
end

test("encode simple object", function()
    local s = Json.Encode({ username = "admin", password = "secret" })
    assert(s == '{"password":"secret","username":"admin"}' or s == '{"username":"admin","password":"secret"}', s)
end)

test("encode array", function()
    local s = Json.Encode({ "a", "b", "c" })
    assert(s == '["a","b","c"]', s)
end)

test("encode nested", function()
    local s = Json.Encode({ a = { b = 1 } })
    assert(s:find('"a"') and s:find('"b"') and s:find('1'), s)
end)

test("decode simple object", function()
    local t = Json.Decode('{"username":"admin","password":"secret"}')
    assert(t.username == "admin")
    assert(t.password == "secret")
end)

test("decode array", function()
    local t = Json.Decode('[1,2,3]')
    assert(#t == 3)
    assert(t[1] == 1)
    assert(t[3] == 3)
end)

test("decode nested", function()
    local t = Json.Decode('{"a":{"b":true}}')
    assert(t.a.b == true)
end)

test("roundtrip", function()
    local original = { name = "test", count = 5, items = { "x", "y" }, active = true }
    local s = Json.Encode(original)
    local decoded = Json.Decode(s)
    assert(decoded.name == "test")
    assert(decoded.count == 5)
    assert(decoded.items[1] == "x")
    assert(decoded.active == true)
end)

print("\nJSON tests completed.")
