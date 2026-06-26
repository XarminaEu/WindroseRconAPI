local HttpServer = {}

local Utils = require("utils")
local net = require("windrose_rcon")

local server_socket = nil
local running = false
local clients = {}

local function parse_request(data)
    local lines = {}
    for line in data:gmatch("([^\r\n]*)\r?\n") do
        table.insert(lines, line)
    end

    -- Capture any trailing content after the last newline as body if it is not empty.
    local last_nl = data:find("\r?\n[^\r\n]*$")
    if not last_nl then
        -- No newline at all; treat entire data as body? No, try to parse first line.
    end

    if #lines == 0 then return nil end

    local first = lines[1]
    local method, path, version = first:match("^(%S+)%s+(%S+)%s+(%S+)$")
    if not method then return nil end

    local headers = {}
    local i = 2
    while i <= #lines and lines[i] ~= "" do
        local key, value = lines[i]:match("^([^:]+):%s*(.*)$")
        if key then
            headers[key:lower()] = value
        end
        i = i + 1
    end

    local body = ""
    if i < #lines then
        body = table.concat(lines, "\n", i + 1)
    end

    -- If there is content after the final newline, append it.
    local content_length = tonumber(headers["content-length"]) or 0
    if content_length > 0 then
        local header_end = data:find("\r\n\r\n", 1, true)
        if header_end then
            local actual_body = data:sub(header_end + 4)
            if #actual_body > #body then
                body = actual_body
            end
        end
    end

    return {
        method = method,
        path = path,
        version = version,
        headers = headers,
        body = body,
    }
end

local function content_type_from_path(path)
    if path:match("%.html$") then return "text/html"
    elseif path:match("%.css$") then return "text/css"
    elseif path:match("%.js$") then return "application/javascript"
    elseif path:match("%.png$") then return "image/png"
    elseif path:match("%.jpg$") or path:match("%.jpeg$") then return "image/jpeg"
    elseif path:match("%.svg$") then return "image/svg+xml"
    elseif path:match("%.ico$") then return "image/x-icon"
    elseif path:match("%.json$") then return "application/json"
    else return "text/plain" end
end

local function send_response(client, status_code, content_type, body)
    if not client or not client.socket or client.responded then return end
    client.responded = true
    local status_text = "OK"
    if status_code == 200 then status_text = "OK"
    elseif status_code == 400 then status_text = "Bad Request"
    elseif status_code == 401 then status_text = "Unauthorized"
    elseif status_code == 404 then status_text = "Not Found"
    elseif status_code == 405 then status_text = "Method Not Allowed"
    elseif status_code == 500 then status_text = "Internal Server Error"
    end

    local response = string.format("HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s",
        status_code, status_text, content_type, #body, body)

    local sent = 0
    while sent < #response do
        local n, err = net.send(client.socket, response:sub(sent + 1))
        if not n then
            Utils.LogDebug("HTTP send failed: " .. tostring(err))
            client.closed = true
            return
        end
        sent = sent + n
    end
end

local function serve_file(client, file_path)
    local file, err = io.open(file_path, "rb")
    if not file then
        send_response(client, 404, "text/plain", "Not found")
        return
    end
    local content = file:read("*a")
    file:close()
    send_response(client, 200, content_type_from_path(file_path), content or "")
end

local function receive_request(client)
    if not client or not client.socket then return nil end

    local buffer = client.buffer or ""
    while true do
        local header_end = buffer:find("\r\n\r\n", 1, true)
        if not header_end then
            local data, err = net.receive(client.socket, 4096)
            if not data then
                if err == "wouldblock" then return nil end
                if err == "closed" then client.closed = true return nil end
                return nil
            end
            buffer = buffer .. data
        else
            local headers_str = buffer:sub(1, header_end + 3)
            local content_length = 0
            for line in headers_str:gmatch("([^\r\n]+)") do
                local key, value = line:match("^([^:]+):%s*(.*)$")
                if key and key:lower() == "content-length" then
                    content_length = tonumber(value) or 0
                end
            end

            local total_needed = header_end + 3 + content_length
            if #buffer >= total_needed then
                client.buffer = buffer:sub(total_needed + 1)
                return buffer:sub(1, total_needed)
            else
                local data, err = net.receive(client.socket, 4096)
                if not data then
                    if err == "wouldblock" then return nil end
                    if err == "closed" then client.closed = true return nil end
                    return nil
                end
                buffer = buffer .. data
            end
        end
    end
end

local function generate_json_response(success, data_or_message, extra)
    local result = { success = success }
    if success then
        if extra then
            for k, v in pairs(extra) do result[k] = v end
        end
        result.data = data_or_message
    else
        result.error = data_or_message
    end
    return result
end

local route_handlers = {}

function HttpServer.RegisterRoute(method, path, handler)
    route_handlers[string.upper(method) .. " " .. path] = handler
end

function HttpServer.Start(config, command_registry, auth)
    if not config.http or not config.http.enabled then return false end

    local host = config.http.host or "0.0.0.0"
    local port = config.http.port or 8780

    local ok, err = net.init()
    if not ok then
        Utils.LogError("HTTP server Winsock init failed: " .. tostring(err))
        return false
    end

    server_socket, err = net.bind(host, port)
    if not server_socket then
        Utils.LogError("HTTP server bind failed: " .. tostring(err))
        return false
    end

    running = true
    Utils.LogInfo(string.format("HTTP REST API listening on http://%s:%d", host, port))

    RegisterHook("/Script/Engine.GameEngine:Tick", function()
        if not running then return end
        local tick_ok, tick_err = pcall(function()
            HttpServer.Tick(config, command_registry, auth)
        end)
        if not tick_ok then
            Utils.LogError("HTTP tick error: " .. tostring(tick_err))
        end
    end)

    return true
end

function HttpServer.Tick(config, command_registry, auth)
    if not running or not server_socket then return end

    local client_socket, err = net.accept(server_socket, 0)
    if client_socket then
        table.insert(clients, {
            socket = client_socket,
            buffer = "",
            closed = false,
            responded = false,
        })
    end

    local i = 1
    while i <= #clients do
        local client = clients[i]
        if client.closed or client.responded then
            net.close(client.socket)
            table.remove(clients, i)
        else
            local request_data = receive_request(client)
            if request_data then
                local request = parse_request(request_data)
                if request then
                    request.client = client
                    HttpServer.HandleRequest(client, request, config, command_registry, auth)
                else
                    send_response(client, 400, "application/json", '{"success":false,"error":"Bad request"}')
                end
                client.closed = true
            elseif client.closed then
                net.close(client.socket)
                table.remove(clients, i)
                i = i - 1
            end
            i = i + 1
        end
    end
end

function HttpServer.HandleRequest(client, request, config, command_registry, auth)
    local route_key = string.upper(request.method) .. " " .. request.path
    local handler = route_handlers[route_key]

    if not handler then
        send_response(client, 404, "application/json", '{"success":false,"error":"Not found"}')
        return
    end

    local ok, status, body = pcall(function()
        return handler(request, config, command_registry, auth)
    end)
    if not ok then
        Utils.LogError("HTTP handler error: " .. tostring(status))
        send_response(client, 500, "application/json", '{"success":false,"error":"Internal server error"}')
        return
    end

    if status and status ~= 0 then
        send_response(client, status, "application/json", body)
    end
end

function HttpServer.ServeFile(client, file_path)
    serve_file(client, file_path)
end

function HttpServer.Stop()
    running = false
    for _, client in ipairs(clients) do
        if not client.closed then
            net.close(client.socket)
        end
    end
    clients = {}
    if server_socket then
        net.close(server_socket)
        server_socket = nil
    end
end

return HttpServer
