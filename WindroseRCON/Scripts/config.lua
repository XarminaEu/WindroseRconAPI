local Config = {}

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

    if not config.admin.password or config.admin.password == "" then
        print("[WindroseRCON] WARNING: admin.password is not set in config_user.lua. Admin commands will be rejected.\n")
    end

    return config
end

return Config
