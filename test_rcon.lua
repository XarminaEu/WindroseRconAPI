-- Standalone RCON protocol test.
-- Starts the in-process RCON server, connects a client, authenticates, and runs a command.

package.path = "WindroseRCON/Scripts/?.lua;" .. package.path
package.cpath = "WindroseRCON/Scripts/?.dll;" .. package.cpath

-- Stub UE4SS globals
_G.RegisterHook = function(name, fn)
    print("[Stub] RegisterHook called:", name)
    _G.tick_fn = fn
end
_G.ExecuteInGameThread = function(fn) fn() end
_G.FindObjects = function(...) return {} end

local Config = require("config")
local Utils = require("utils")
local Auth = require("auth")
local CommandRegistry = require("command_registry")
local Commands = require("commands")
local RconServer = require("rcon_server")

local config = Config.Load()
config.admin.password = "testpass123"
config.rcon.password = "testpass123"
config.rcon.host = "127.0.0.1"
config.rcon.port = 25575
Utils.SetConfig(config)
Auth.Init(config)
if not config.rcon.password or config.rcon.password == "" then
    config.rcon.password = config.admin.password
end
Commands.RegisterAll()

RconServer.Start(config)

local net = require("windrose_rcon")
net.init()

local function pack_int32_le(value)
    local b1 = value % 256
    value = math.floor(value / 256)
    local b2 = value % 256
    value = math.floor(value / 256)
    local b3 = value % 256
    value = math.floor(value / 256)
    local b4 = value % 256
    return string.char(b1, b2, b3, b4)
end

local function make_packet(request_id, packet_type, body)
    local payload = pack_int32_le(request_id) .. pack_int32_le(packet_type) .. body .. "\0\0"
    return pack_int32_le(#payload) .. payload
end

local function recv_packet(sock)
    local buffer = ""
    while #buffer < 4 do
        local data, err = net.receive(sock, 1024)
        if not data then
            if err == "wouldblock" then
                -- tick server
                if _G.tick_fn then _G.tick_fn() end
            else
                error("recv failed: " .. tostring(err))
            end
        else
            buffer = buffer .. data
        end
    end
    local length = string.byte(buffer, 1) + string.byte(buffer, 2) * 256 + string.byte(buffer, 3) * 65536 + string.byte(buffer, 4) * 16777216
    while #buffer < 4 + length do
        local data, err = net.receive(sock, 1024)
        if not data then
            if err == "wouldblock" then
                if _G.tick_fn then _G.tick_fn() end
            else
                error("recv failed: " .. tostring(err))
            end
        else
            buffer = buffer .. data
        end
    end
    local packet = buffer:sub(5, 4 + length)
    local request_id = string.byte(packet, 1) + string.byte(packet, 2) * 256 + string.byte(packet, 3) * 65536 + string.byte(packet, 4) * 16777216
    local packet_type = string.byte(packet, 5) + string.byte(packet, 6) * 256 + string.byte(packet, 7) * 65536 + string.byte(packet, 8) * 16777216
    local body_end = #packet - 1
    local body = packet:sub(9, body_end - 1)
    return request_id, packet_type, body
end

local client, err = net.connect("127.0.0.1", 25575, 2000)
if not client then
    error("connect failed: " .. tostring(err))
end
print("RCON client connected")

-- tick a few times to accept the client
for i = 1, 10 do
    if _G.tick_fn then _G.tick_fn() end
end

-- Send auth packet
local auth_packet = make_packet(1, 3, "testpass123")
local sent, serr = net.send(client, auth_packet)
if not sent then error("auth send failed: " .. tostring(serr)) end
print("Auth packet sent")

-- tick until auth response
local req_id, ptype, body = recv_packet(client)
print("Auth response:", req_id, ptype, body)
assert(req_id == 1 and ptype == 2, "expected auth response")

-- Send command
local cmd_packet = make_packet(2, 2, "help")
local sent2, serr2 = net.send(client, cmd_packet)
if not sent2 then error("cmd send failed: " .. tostring(serr2)) end
print("Command packet sent")

local req_id2, ptype2, body2 = recv_packet(client)
print("Command response:", req_id2, ptype2, body2)
assert(req_id2 == 2 and ptype2 == 0, "expected command response")
assert(body2:find("Available commands") ~= nil, "expected help text")

net.close(client)
net.cleanup()
RconServer.Stop()
print("RCON protocol test passed")
