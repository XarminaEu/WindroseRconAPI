local RconServer = {}

local Utils = require("utils")
local CommandRegistry = require("command_registry")

local SERVERDATA_RESPONSE_VALUE = 0
local SERVERDATA_EXECCOMMAND = 2
local SERVERDATA_AUTH_RESPONSE = 2
local SERVERDATA_AUTH = 3

local net = nil
local server_socket = nil
local clients = {}
local config = nil
local running = false

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

local function unpack_int32_le(data, offset)
    offset = offset or 1
    local b1, b2, b3, b4 = data:byte(offset, offset + 3)
    if not b1 then return nil end
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function parse_packet(data)
    if #data < 4 then return nil, data end
    local length = unpack_int32_le(data, 1)
    if length == nil or #data < 4 + length then return nil, data end

    local request_id = unpack_int32_le(data, 5)
    local packet_type = unpack_int32_le(data, 9)
    local body_end = 4 + length - 1
    local body = data:sub(13, body_end - 1)
    local remaining = data:sub(4 + length + 1)
    return { request_id = request_id, packet_type = packet_type, body = body }, remaining
end

local function send_packet(client, request_id, packet_type, body)
    if not client or not client.socket then return end
    local body_bytes = body .. "\0\0"
    local packet = pack_int32_le(request_id) .. pack_int32_le(packet_type) .. body_bytes
    local packet_with_len = pack_int32_le(#packet) .. packet

    local sent = 0
    local ok, err = pcall(function()
        while sent < #packet_with_len do
            local chunk = packet_with_len:sub(sent + 1)
            local n, send_err = net.send(client.socket, chunk)
            if not n then error(send_err or "send failed") end
            sent = sent + n
        end
    end)
    if not ok then
        Utils.LogDebug("Send failed: " .. tostring(err))
        client.closed = true
    end
end

local function handle_client_packet(client, packet)
    if packet.packet_type == SERVERDATA_AUTH then
        if packet.body == config.rcon.password then
            client.authenticated = true
            send_packet(client, packet.request_id, SERVERDATA_AUTH_RESPONSE, "")
            Utils.LogInfo("Client authenticated from socket " .. client.socket)
        else
            client.authenticated = false
            send_packet(client, -1, SERVERDATA_AUTH_RESPONSE, "")
            Utils.LogWarn("Failed RCON auth from socket " .. client.socket)
        end
    elseif packet.packet_type == SERVERDATA_EXECCOMMAND then
        if not client.authenticated then
            send_packet(client, packet.request_id, SERVERDATA_RESPONSE_VALUE, "Not authenticated")
            return
        end

        Utils.LogInfo("RCON command: " .. packet.body)
        local parts = Utils.QuoteAwareSplit(packet.body)
        local cmd_name = parts[1] and parts[1]:lower() or ""
        table.remove(parts, 1)

        local result = CommandRegistry.Execute(cmd_name, parts, { config = config, source = "rcon", session_id = client.socket })
        send_packet(client, packet.request_id, SERVERDATA_RESPONSE_VALUE, result.message or "")
    elseif packet.packet_type == SERVERDATA_RESPONSE_VALUE then
        send_packet(client, packet.request_id, SERVERDATA_RESPONSE_VALUE, "")
    end
end

local function accept_new_client()
    local client_socket, err = net.accept(server_socket, 0)
    if client_socket then
        table.insert(clients, {
            socket = client_socket,
            buffer = "",
            authenticated = false,
            closed = false,
        })
        Utils.LogInfo("New RCON client connected (socket " .. client_socket .. ")")
    end
end

local function process_clients()
    local sockets = {}
    for _, client in ipairs(clients) do
        if not client.closed then
            table.insert(sockets, client.socket)
        end
    end

    if #sockets == 0 then return end

    local ready = net.select(sockets, 0)
    if not ready then return end

    local ready_set = {}
    for _, sock in ipairs(ready) do
        ready_set[sock] = true
    end

    local i = 1
    while i <= #clients do
        local client = clients[i]
        if client.closed then
            net.close(client.socket)
            table.remove(clients, i)
        elseif ready_set[client.socket] then
            local data, err = net.receive(client.socket, 4096)
            if not data then
                if err ~= "wouldblock" then
                    client.closed = true
                end
                i = i + 1
            else
                client.buffer = client.buffer .. data
                while true do
                    local packet, remaining = parse_packet(client.buffer)
                    if not packet then break end
                    client.buffer = remaining
                    handle_client_packet(client, packet)
                end
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

function RconServer.Start(module_config)
    config = module_config
    if not config.rcon.enabled then
        Utils.LogInfo("RCON is disabled in config")
        return false
    end

    local ok, loaded = pcall(function()
        return require("windrose_rcon")
    end)
    if not ok or not loaded then
        Utils.LogError("Failed to load windrose_rcon.dll: " .. tostring(loaded))
        Utils.LogError("Make sure windrose_rcon.dll is in WindroseRCON/Scripts/")
        return false
    end
    net = loaded

    local init_ok, init_err = net.init()
    if not init_ok then
        Utils.LogError("windrose_rcon init failed: " .. tostring(init_err))
        return false
    end

    local host = "0.0.0.0"
    local port = 25575
    if config.rcon.port then port = config.rcon.port end
    if config.rcon.host then host = config.rcon.host end

    server_socket, err = net.bind(host, port)
    if not server_socket then
        Utils.LogError("Failed to bind RCON server: " .. tostring(err))
        return false
    end

    running = true
    Utils.LogInfo(string.format("RCON server listening on %s:%d", host, port))

    RegisterHook("/Script/Engine.GameEngine:Tick", function()
        if not running then return end
        local ok, err = pcall(function()
            accept_new_client()
            process_clients()
        end)
        if not ok then
            Utils.LogError("RCON tick error: " .. tostring(err))
        end
    end)

    return true
end

function RconServer.Stop()
    running = false
    for _, client in ipairs(clients) do
        pcall(function() net.close(client.socket) end)
    end
    clients = {}
    if server_socket then
        pcall(function() net.close(server_socket) end)
        server_socket = nil
    end
    if net then
        pcall(function() net.cleanup() end)
    end
end

return RconServer
