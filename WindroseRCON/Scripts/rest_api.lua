local RestApi = {}

local HttpServer = require("http_server")
local Utils = require("utils")
local Json = require("json")

local active_tokens = {}

local function generate_token()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local token = ""
    for _ = 1, 32 do
        local idx = math.random(1, #chars)
        token = token .. chars:sub(idx, idx)
    end
    return token
end

local function require_auth(request, config)
    local auth_header = request.headers["authorization"] or ""
    local token = auth_header:match("^Bearer%s+(.+)$")
    if not token or not active_tokens[token] then
        return false
    end
    return true
end

function RestApi.Start(config, command_registry, auth)
    if not config.http or not config.http.enabled then return false end

    HttpServer.RegisterRoute("GET", "/api/health", function(request, cfg)
        return 200, Json.Encode({ status = "ok", version = "1.0.0", timestamp = os.time() })
    end)

    HttpServer.RegisterRoute("POST", "/api/login", function(request, cfg)
        local body = Json.Decode(request.body or "{}")
        if not body then
            return 400, Json.Encode({ success = false, error = "Invalid JSON" })
        end
        if body.username ~= "admin" then
            return 401, Json.Encode({ success = false, error = "Username must be admin" })
        end
        if not body.password or body.password ~= cfg.admin.password then
            return 401, Json.Encode({ success = false, error = "Invalid password" })
        end
        local token = generate_token()
        active_tokens[token] = true
        return 200, Json.Encode({ success = true, token = token })
    end)

    HttpServer.RegisterRoute("POST", "/api/logout", function(request, cfg)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local auth_header = request.headers["authorization"] or ""
        local token = auth_header:match("^Bearer%s+(.+)$")
        if token then active_tokens[token] = nil end
        return 200, Json.Encode({ success = true })
    end)

    HttpServer.RegisterRoute("POST", "/api/command", function(request, cfg, registry, auth_module)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local body = Json.Decode(request.body or "{}")
        if not body or not body.command then
            return 400, Json.Encode({ success = false, error = "Missing command" })
        end
        local parts = Utils.QuoteAwareSplit(body.command)
        local cmd_name = parts[1] and parts[1]:lower() or ""
        table.remove(parts, 1)
        local result = registry.Execute(cmd_name, parts, { config = cfg, source = "rest", session_id = "rest" })
        return 200, Json.Encode({ success = result.success, message = result.message or "" })
    end)

    HttpServer.RegisterRoute("GET", "/api/commands", function(request, cfg, registry)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local all = registry.GetAll()
        local commands = {}
        for name, cmd in pairs(all) do
            commands[name] = { description = cmd.description, args = cmd.args, permission = cmd.permission }
        end
        return 200, Json.Encode({ success = true, commands = commands })
    end)

    HttpServer.RegisterRoute("GET", "/api/players", function(request, cfg, registry)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local result = registry.Execute("players", {}, { config = cfg, source = "rest", session_id = "rest" })
        return 200, Json.Encode({ success = result.success, message = result.message or "" })
    end)

    return HttpServer.Start(config, command_registry, auth)
end

function RestApi.Stop()
    HttpServer.Stop()
    active_tokens = {}
end

return RestApi
