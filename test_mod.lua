-- Standalone test for WindroseRCON Lua logic.
-- Run with: lua_test.exe test_mod.lua
-- This stubs UE4SS functions so the command registry and auth can be tested.

package.path = "WindroseRCON/Scripts/?.lua;" .. package.path
package.cpath = "WindroseRCON/Scripts/?.dll;" .. package.cpath

-- Stub UE4SS global functions
_G.RegisterHook = function(...) end
_G.ExecuteInGameThread = function(fn) fn() end
_G.FindObjects = function(...) return {} end
_G.FindObject = function(...) return { IsValid = function() return false end } end

-- Stub FOutputDevice
local FOutputDevice = { message = nil }
FOutputDevice.__index = FOutputDevice
function FOutputDevice:new()
    local o = { message = nil }
    setmetatable(o, self)
    return o
end
function FOutputDevice:Log(msg)
    self.message = msg
    print("[Console] " .. msg)
end
function FOutputDevice:IsValid() return true end

local Config = require("config")
local Utils = require("utils")
local Auth = require("auth")
local CommandRegistry = require("command_registry")
local Commands = require("commands")

local config = Config.Load()
config.admin.password = "testpass123"
config.rcon.password = "testpass123"
Utils.SetConfig(config)
Auth.Init(config)
Commands.RegisterAll()

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("PASS: " .. name)
    else
        print("FAIL: " .. name .. " - " .. tostring(err))
    end
end

test("login requires password", function()
    local result = CommandRegistry.Execute("login", {}, { source = "console", session_id = "test" })
    assert(result.success == false, "expected failure without password")
end)

test("login with wrong password fails", function()
    local result = CommandRegistry.Execute("login", { "wrong" }, { source = "console", session_id = "test" })
    assert(result.success == false, "expected failure with wrong password")
end)

test("login with correct password succeeds", function()
    local result = CommandRegistry.Execute("login", { "testpass123" }, { source = "console", session_id = "test" })
    assert(result.success == true, "expected success")
end)

test("admin command rejected before login", function()
    local result = CommandRegistry.Execute("players", {}, { source = "console", session_id = "fresh" })
    assert(result.success == false, "expected rejection")
end)

test("admin command allowed after login", function()
    local result = CommandRegistry.Execute("players", {}, { source = "console", session_id = "test" })
    assert(result.success == true, "expected success")
end)

test("logout works", function()
    local result = CommandRegistry.Execute("logout", {}, { source = "console", session_id = "test" })
    assert(result.success == true, "expected success")
    local result2 = CommandRegistry.Execute("players", {}, { source = "console", session_id = "test" })
    assert(result2.success == false, "expected rejection after logout")
end)

test("rcon source is trusted without explicit login", function()
    local result = CommandRegistry.Execute("players", {}, { source = "rcon", session_id = 123 })
    assert(result.success == true, "expected success for rcon source")
end)

test("help is public", function()
    local result = CommandRegistry.Execute("help", {}, { source = "console", session_id = "public" })
    assert(result.success == true, "expected success")
end)

print("\nAll tests completed.")
