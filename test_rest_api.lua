-- Standalone test for REST API and HTTP POST functionality.

package.path = "WindroseRCON/Scripts/?.lua;" .. package.path
package.cpath = "WindroseRCON/Scripts/?.dll;" .. package.cpath

_G.RegisterHook = function(name, fn)
    _G.tick_fn = fn
end
_G.ExecuteInGameThread = function(fn) fn() end
_G.FindObjects = function(...) return {} end

local Config = require("config")
local Utils = require("utils")
local Auth = require("auth")
local CommandRegistry = require("command_registry")
local Commands = require("commands")
local RestApi = require("rest_api")
local net = require("windrose_rcon")

local config = Config.Load()
config.admin.password = "testpass123"
config.rcon.password = "testpass123"
config.http.enabled = true
config.http.host = "127.0.0.1"
config.http.port = 8780
config.discord.webhook_url = ""
Utils.SetConfig(config)
Auth.Init(config)
Commands.RegisterAll()

RestApi.Start(config, CommandRegistry, Auth)
net.init()

local function send_http_request(method, path, body, auth_token)
    local headers = {}
    if body then
        table.insert(headers, "Content-Type: application/json")
        table.insert(headers, "Content-Length: " .. #body)
    end
    if auth_token then
        table.insert(headers, "Authorization: Bearer " .. auth_token)
    end

    local request = method .. " " .. path .. " HTTP/1.1\r\nHost: 127.0.0.1:8780\r\nConnection: close\r\n"
    for _, h in ipairs(headers) do
        request = request .. h .. "\r\n"
    end
    request = request .. "\r\n"
    if body then
        request = request .. body
    end

    local client, err = net.connect("127.0.0.1", 8780, 2000)
    if not client then error("connect failed: " .. tostring(err)) end

    -- tick to accept the client
    for _ = 1, 5 do
        if _G.tick_fn then _G.tick_fn() end
    end

    local sent = 0
    while sent < #request do
        local n, serr = net.send(client, request:sub(sent + 1))
        if not n then error("send failed: " .. tostring(serr)) end
        sent = sent + n
    end

    -- tick to process the request
    for _ = 1, 10 do
        if _G.tick_fn then _G.tick_fn() end
    end

    local response = ""
    while true do
        local data, rerr = net.receive(client, 4096)
        if not data then
            if rerr == "wouldblock" then
                if _G.tick_fn then _G.tick_fn() end
            else
                break
            end
        else
            response = response .. data
            if response:find("\r\n\r\n", 1, true) then
                -- check content length
                local cl = response:match("Content%-Length:%s*(%d+)")
                if cl then
                    local header_end = response:find("\r\n\r\n", 1, true)
                    if #response >= header_end + 3 + tonumber(cl) then break end
                else
                    break
                end
            end
        end
    end

    net.close(client)
    return response
end

local function extract_body(response)
    local header_end = response:find("\r\n\r\n", 1, true)
    if not header_end then return nil end
    return response:sub(header_end + 4)
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then print("PASS: " .. name) else print("FAIL: " .. name .. " - " .. tostring(err)) end
end

test("health endpoint returns ok", function()
    local response = send_http_request("GET", "/api/health", nil, nil)
    local body = extract_body(response)
    assert(body and body:find('"status":"ok"'), "expected ok status")
end)

local token = nil
test("login with correct password returns token", function()
    local response = send_http_request("POST", "/api/login", '{"username":"admin","password":"testpass123"}', nil)
    local body = extract_body(response)
    assert(body and body:find('"success":true'), "expected success")
    token = body:match('"token":"([^"]+)"')
    assert(token, "expected token in response")
end)

test("login with wrong password fails", function()
    local response = send_http_request("POST", "/api/login", '{"username":"admin","password":"wrong"}', nil)
    local body = extract_body(response)
    assert(body and body:find('"success":false'), "expected failure")
end)

test("command endpoint with token executes command", function()
    local response = send_http_request("POST", "/api/command", '{"command":"help"}', token)
    local body = extract_body(response)
    assert(body and body:find('"success":true'), "expected success")
    assert(body:find("Available commands"), "expected help text")
end)

test("command endpoint without token fails", function()
    local response = send_http_request("POST", "/api/command", '{"command":"help"}', nil)
    local body = extract_body(response)
    assert(body and body:find('"success":false'), "expected failure")
end)

test("http_post to invalid URL fails", function()
    local ok, status, resp = net.http_post("http://127.0.0.1:1/test", "{}", "application/json", 500)
    assert(ok == false, "expected failure for invalid URL")
end)

RestApi.Stop()
net.cleanup()
print("\nREST API tests completed.")
