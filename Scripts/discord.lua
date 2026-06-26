local Discord = {}

local Utils = require("utils")
local net = require("windrose_rcon")
local Json = require("json")

function Discord.Init(config)
    Discord.Config = config
end

function Discord.SendMessage(message, username)
    local config = Discord.Config
    if not config or not config.discord or not config.discord.webhook_url or config.discord.webhook_url == "" then
        return false, "Discord webhook not configured"
    end

    local payload = {
        content = message,
        username = username or config.discord.username or "WindroseRCON",
    }

    local body = Json.Encode(payload)
    local ok, status, response = net.http_post(config.discord.webhook_url, body, "application/json", 10000)
    if not ok then
        Utils.LogWarn("Discord webhook failed: " .. tostring(status) .. " " .. tostring(response))
        return false, tostring(response)
    end
    Utils.LogInfo("Discord webhook sent: " .. message)
    return true, nil
end

function Discord.BroadcastToDiscord(message)
    return Discord.SendMessage(message, "Windrose Server")
end

return Discord
