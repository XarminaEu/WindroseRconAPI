-- User configuration for WindroseRCON
-- Copy this file and edit the values. It is loaded automatically by config.lua.

return {
    rcon = {
        enabled = true,
        host = "0.0.0.0",
        port = 25575,
        password = "",  -- Leave empty to use admin.password. Set separately if you want a different RCON password.
        fallback_file_bridge = true,
    },
    admin = {
        password = "",  -- REQUIRED. Set a strong admin password.
        -- Add Steam IDs that should always be treated as admins (without platform prefix)
        steam_ids = {
            -- "76561198000000000",
        },
        -- Add IP addresses that are allowed to use RCON
        ip_whitelist = {
            -- "127.0.0.1",
        },
    },
    http = {
        enabled = true,
        host = "0.0.0.0",
        port = 8780,
    },
    discord = {
        webhook_url = "",  -- Paste your Discord webhook URL here to forward in-game chat.
        username = "Windrose Server",
    },
    general = {
        log_level = "info",  -- debug, info, warn, error
        command_prefix = "/",
    },
}
