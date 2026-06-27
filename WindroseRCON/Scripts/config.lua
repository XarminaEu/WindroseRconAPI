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
    local ok, loaded = pcall(function()
        return require("config_user")
    end)
    if ok and type(loaded) == "table" then
        user_config = loaded
    else
        print("[WindroseRCON] config_user.lua not found or invalid, using defaults\n")
    end
    local config = DeepMerge(DeepMerge({}, Config.Defaults), user_config)
    local runtime_config = LoadRuntimeConfig(RUNTIME_CONFIG_PATH)
    config = DeepMerge(config, runtime_config)

    if not config.admin.password or config.admin.password == "" then
        print("[WindroseRCON] WARNING: admin.password is not set in config_user.lua. Admin commands will be rejected.\n")
    end

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
