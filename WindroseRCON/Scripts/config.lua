local Config = {}

local Json = require("json")
local Utils = require("utils")
local RUNTIME_CONFIG_PATH = "WindroseRCON/Data/config_runtime.json"

Config.Defaults = {
    rcon = {
        enabled = true,
        host = "0.0.0.0",
        port = 25575,
        password = "changeme",
        fallback_file_bridge = true,
        command_file = "WindroseRCON/Data/rcon_commands.txt",
        response_file = "WindroseRCON/Data/rcon_responses.txt",
        log_file = "WindroseRCON/Data/rcon_log.txt",
    },
    admin = {
        password = "",  -- REQUIRED. Admin password for console/file-bridge commands.
        steam_ids = {},
        ip_whitelist = {},
    },
    http = {
        enabled = true,
        host = "0.0.0.0",
        port = 8780,
    },
    discord = {
        webhook_url = "",  -- Discord webhook URL for in-game chat forwarding.
        username = "Windrose Server",
    },
    general = {
        log_level = "info",
        command_prefix = "/",
    },
}

local function DeepMerge(base, override)
    for key, value in pairs(override or {}) do
        if type(value) == "table" and type(base[key]) == "table" then
            DeepMerge(base[key], value)
        else
            base[key] = value
        end
    end
    return base
end

local function LoadRuntimeConfig(path)
    local file = io.open(path, "r")
    if not file then return {} end
    local content = file:read("*a")
    file:close()
    local data = Json.Decode(content)
    if type(data) ~= "table" then return {} end
    return data
end

function Config.Load()
    local user_config = {}
    local config_path = package.searchpath("config_user", package.path) or "WindroseRCON/Scripts/config_user.lua"
    local ok, loaded = pcall(function()
        return require("config_user")
    end)
    if ok and type(loaded) == "table" then
        user_config = loaded
        print("[WindroseRCON] config_user.lua loaded successfully from: " .. tostring(config_path) .. "\n")
    else
        print("[WindroseRCON] config_user.lua not found or invalid, using defaults. Searched: " .. tostring(config_path) .. "\n")
    end
    -- config_user.lua is the source of truth for ports, passwords, and general settings.
    -- runtime config only overrides whitelist/steam_ids so dashboard edits stay effective.
    local config = DeepMerge(DeepMerge({}, Config.Defaults), user_config)
    local runtime_config = LoadRuntimeConfig(RUNTIME_CONFIG_PATH)
    if runtime_config and next(runtime_config) then
        print("[WindroseRCON] Runtime config loaded from: " .. RUNTIME_CONFIG_PATH .. "\n")
    end
    if runtime_config and runtime_config.admin then
        if runtime_config.admin.ip_whitelist then
            config.admin.ip_whitelist = runtime_config.admin.ip_whitelist
        end
        if runtime_config.admin.steam_ids then
            config.admin.steam_ids = runtime_config.admin.steam_ids
        end
    end

    if not config.admin.password or config.admin.password == "" then
        print("[WindroseRCON] WARNING: admin.password is not set in config_user.lua. Admin commands will be rejected.\n")
    else
        print("[WindroseRCON] admin.password is set.\n")
    end

    print(string.format("[WindroseRCON] Config loaded: RCON %s:%d, HTTP %s:%d\n", config.rcon.host, config.rcon.port, config.http.host, config.http.port))

    return config
end

function Config.SaveRuntimeConfig(runtime_config)
    local ok = Utils.WriteFile(RUNTIME_CONFIG_PATH, Json.Encode(runtime_config))
    if not ok then
        Utils.LogError("Failed to save runtime config to " .. RUNTIME_CONFIG_PATH .. ". Make sure the WindroseRCON/Data folder exists.")
    end
    return ok
end

function Config.LoadRuntimeConfig()
    return LoadRuntimeConfig(RUNTIME_CONFIG_PATH)
end

return Config
