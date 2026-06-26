local RestApi = {}

local HttpServer = require("http_server")
local Utils = require("utils")
local Json = require("json")
local Config = require("config")

local active_tokens = {}

local BANLIST_PATH = "WindroseRCON/Data/banlist.json"

local function get_dashboard_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then source = source:sub(2) end
    local dir = source:match("^(.*)[/\\]") or ""
    return dir .. "/dashboard"
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

local function load_banlist()
    local content = read_file(BANLIST_PATH)
    if not content then return {} end
    local data = Json.Decode(content)
    if type(data) ~= "table" then return {} end
    return data
end

local function save_banlist(banlist)
    return write_file(BANLIST_PATH, Json.Encode(banlist))
end

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

    HttpServer.RegisterRoute("GET", "/api/config", function(request, cfg)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local safe = {
            admin = { password = "", steam_ids = cfg.admin.steam_ids, ip_whitelist = cfg.admin.ip_whitelist },
            rcon = { password = "", enabled = cfg.rcon.enabled, host = cfg.rcon.host, port = cfg.rcon.port },
            http = cfg.http,
            discord = cfg.discord,
            general = cfg.general,
        }
        return 200, Json.Encode({ success = true, config = safe })
    end)

    HttpServer.RegisterRoute("POST", "/api/config", function(request, cfg)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local body = Json.Decode(request.body or "{}")
        if not body then
            return 400, Json.Encode({ success = false, error = "Invalid JSON" })
        end
        local runtime = Config.LoadRuntimeConfig()
        if body.admin_password and body.admin_password ~= "" then
            runtime.admin = runtime.admin or {}
            runtime.admin.password = body.admin_password
        end
        if body.rcon_password and body.rcon_password ~= "" then
            runtime.rcon = runtime.rcon or {}
            runtime.rcon.password = body.rcon_password
        end
        if body.discord_webhook_url ~= nil then
            runtime.discord = runtime.discord or {}
            runtime.discord.webhook_url = body.discord_webhook_url
        end
        if body.http_port then
            runtime.http = runtime.http or {}
            runtime.http.port = body.http_port
        end
        if body.log_level then
            runtime.general = runtime.general or {}
            runtime.general.log_level = body.log_level
        end
        if Config.SaveRuntimeConfig(runtime) then
            return 200, Json.Encode({ success = true, message = "Saved. Restart required for some changes to take effect." })
        else
            return 500, Json.Encode({ success = false, error = "Failed to save config" })
        end
    end)

    HttpServer.RegisterRoute("GET", "/api/whitelist", function(request, cfg)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        return 200, Json.Encode({ success = true, whitelist = { steam_ids = cfg.admin.steam_ids, ip_whitelist = cfg.admin.ip_whitelist } })
    end)

    HttpServer.RegisterRoute("POST", "/api/whitelist", function(request, cfg)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local body = Json.Decode(request.body or "{}")
        if not body then
            return 400, Json.Encode({ success = false, error = "Invalid JSON" })
        end
        local runtime = Config.LoadRuntimeConfig()
        runtime.admin = runtime.admin or {}
        runtime.admin.steam_ids = body.steam_ids or {}
        runtime.admin.ip_whitelist = body.ip_whitelist or {}
        if Config.SaveRuntimeConfig(runtime) then
            cfg.admin.steam_ids = runtime.admin.steam_ids
            cfg.admin.ip_whitelist = runtime.admin.ip_whitelist
            return 200, Json.Encode({ success = true, message = "Whitelist saved." })
        else
            return 500, Json.Encode({ success = false, error = "Failed to save whitelist" })
        end
    end)

    HttpServer.RegisterRoute("GET", "/api/banlist", function(request, cfg)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        return 200, Json.Encode({ success = true, banlist = load_banlist() })
    end)

    HttpServer.RegisterRoute("POST", "/api/banlist", function(request, cfg, registry)
        if not require_auth(request, cfg) then
            return 401, Json.Encode({ success = false, error = "Unauthorized" })
        end
        local body = Json.Decode(request.body or "{}")
        if not body or not body.action then
            return 400, Json.Encode({ success = false, error = "Invalid JSON" })
        end
        local banlist = load_banlist()
        if body.action == "ban" then
            if not body.userid then
                return 400, Json.Encode({ success = false, error = "Missing userid" })
            end
            table.insert(banlist, { userid = body.userid, reason = body.reason or "" })
            registry.Execute("ban", { body.userid, body.reason or "" }, { config = cfg, source = "rest", session_id = "rest" })
        elseif body.action == "unban" then
            if not body.index then
                return 400, Json.Encode({ success = false, error = "Missing index" })
            end
            table.remove(banlist, body.index)
        end
        if save_banlist(banlist) then
            return 200, Json.Encode({ success = true, banlist = banlist })
        else
            return 500, Json.Encode({ success = false, error = "Failed to save banlist" })
        end
    end)

    local dashboard_dir = get_dashboard_dir()
    HttpServer.RegisterRoute("GET", "/", function(request, cfg)
        HttpServer.ServeFile(request.client, dashboard_dir .. "/index.html")
        return 0, "" -- already responded
    end)
    HttpServer.RegisterRoute("GET", "/style.css", function(request, cfg)
        HttpServer.ServeFile(request.client, dashboard_dir .. "/style.css")
        return 0, ""
    end)
    HttpServer.RegisterRoute("GET", "/app.js", function(request, cfg)
        HttpServer.ServeFile(request.client, dashboard_dir .. "/app.js")
        return 0, ""
    end)

    return HttpServer.Start(config, command_registry, auth)
end

function RestApi.Stop()
    HttpServer.Stop()
    active_tokens = {}
end

return RestApi
