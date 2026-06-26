local Commands = {}
local CommandRegistry = require("command_registry")
local GameApi = require("game_api")
local Utils = require("utils")
local Auth = require("auth")
local Discord = require("discord")

local function FormatPlayerList()
    local players = GameApi.GetAllPlayerStates()
    if #players == 0 then
        return { success = true, message = "No players online" }
    end

    local lines = { string.format("%-5s %-25s %-15s %-10s %-30s", "ID", "Name", "PlayerId", "Ping", "Position") }
    for i, player_state in ipairs(players) do
        local name = player_state:GetPlayerName() or "Unknown"
        local player_id = tostring(player_state.PlayerId or "N/A")
        local ping = "N/A"
        if player_state.GetPingInMilliseconds then
            ping = tostring(player_state:GetPingInMilliseconds())
        end
        local pos = GameApi.GetPlayerPosition(player_state)
        local pos_str = pos and string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z) or "N/A"
        table.insert(lines, string.format("%-5d %-25s %-15s %-10s %-30s", i, name, player_id, ping, pos_str))
    end
    return { success = true, message = table.concat(lines, "\n") }
end

local function FormatHelp()
    local all = CommandRegistry.GetAll()
    local names = {}
    for name, _ in pairs(all) do table.insert(names, name) end
    table.sort(names)

    local lines = { "Available commands:" }
    for _, name in ipairs(names) do
        local cmd = all[name]
        local arg_str = cmd.args and #cmd.args > 0 and table.concat(cmd.args, " ") or ""
        table.insert(lines, string.format("  %s %s - %s", name, arg_str, cmd.description))
    end
    return { success = true, message = table.concat(lines, "\n") }
end

function Commands.RegisterAll()
    CommandRegistry.Register("login", function(args, ctx)
        return Auth.HandleLogin(ctx.session_id, args)
    end, "Authenticates the session with the admin password", {"<password>"}, "any")

    CommandRegistry.Register("logout", function(args, ctx)
        Auth.ClearSession(ctx.session_id)
        return { success = true, message = "Session logged out." }
    end, "Logs out the current session", {}, "any")

    CommandRegistry.Register("help", FormatHelp, "Lists all available commands", {}, "any")
    CommandRegistry.Register("players", FormatPlayerList, "Lists online players", {}, "admin")
    CommandRegistry.Register("kick", function(args, ctx)
        if #args < 1 then return { success = false, message = "Usage: kick <UserId> [Reason]" } end
        local target = GameApi.FindPlayerById(args[1])
        if not target then return { success = false, message = "Player not found: " .. args[1] } end
        local reason = args[2] or "Kicked by admin"
        GameApi.KickPlayer(target, reason)
        return { success = true, message = "Kicked player " .. target:GetPlayerName() .. ": " .. reason }
    end, "Kicks a player from the server", {"<UserId>", "[Reason]"}, "admin")

    CommandRegistry.Register("ban", function(args, ctx)
        if #args < 1 then return { success = false, message = "Usage: ban <UserId> [Reason]" } end
        local target = GameApi.FindPlayerById(args[1])
        if not target then return { success = false, message = "Player not found: " .. args[1] } end
        local reason = args[2] or "Banned by admin"
        GameApi.KickPlayer(target, reason)
        Utils.AppendFile(ctx.config.rcon.log_file or "WindroseRCON/Data/bans.txt",
            string.format("BANNED %s %s %s\n", target:GetPlayerName(), tostring(target.PlayerId or ""), reason))
        return { success = true, message = "Banned and kicked player " .. target:GetPlayerName() .. ": " .. reason }
    end, "Bans and kicks a player", {"<UserId>", "[Reason]"}, "admin")

    CommandRegistry.Register("tp", function(args, ctx)
        if #args < 2 then return { success = false, message = "Usage: tp <UserId> <X> <Y> [Z]" } end
        local target = GameApi.FindPlayerById(args[1])
        if not target then return { success = false, message = "Player not found: " .. args[1] } end
        local x = tonumber(args[2])
        local y = tonumber(args[3])
        local z = tonumber(args[4]) or 0
        if not x or not y then return { success = false, message = "Invalid coordinates" } end
        GameApi.SetPlayerPosition(target, x, y, z)
        return { success = true, message = string.format("Teleported %s to %.1f %.1f %.1f", target:GetPlayerName(), x, y, z) }
    end, "Teleports a player to coordinates", {"<UserId>", "<X>", "<Y>", "[Z]"}, "admin")

    CommandRegistry.Register("getpos", function(args, ctx)
        local target
        if #args >= 1 then
            target = GameApi.FindPlayerById(args[1])
            if not target then return { success = false, message = "Player not found: " .. args[1] } end
        else
            return { success = false, message = "Usage: getpos <UserId>" }
        end
        local pos = GameApi.GetPlayerPosition(target)
        if not pos then return { success = false, message = "Could not get position" } end
        return { success = true, message = string.format("%s position: %.3f %.3f %.3f", target:GetPlayerName(), pos.X, pos.Y, pos.Z) }
    end, "Gets player position", {"[UserId]"}, "admin")

    CommandRegistry.Register("broadcast", function(args, ctx)
        if #args < 1 then return { success = false, message = "Usage: broadcast <Message>" } end
        local message = table.concat(args, " ")
        GameApi.BroadcastMessage(message)
        Discord.BroadcastToDiscord("[Broadcast] " .. message)
        return { success = true, message = "Broadcasted: " .. message }
    end, "Sends a message to all players and Discord", {"<Message>"}, "admin")

    CommandRegistry.Register("say", function(args, ctx)
        if #args < 2 then return { success = false, message = "Usage: say <UserId> <Message>" } end
        local target = GameApi.FindPlayerById(args[1])
        if not target then return { success = false, message = "Player not found: " .. args[1] } end
        local message = table.concat(args, " ", 2)
        GameApi.SendPlayerMessage(target, message, "Say")
        Discord.SendMessage("[Say to " .. target:GetPlayerName() .. "] " .. message, "Windrose Server")
        return { success = true, message = "Sent message to " .. target:GetPlayerName() }
    end, "Sends a private message to a player and Discord", {"<UserId>", "<Message>"}, "admin")

    CommandRegistry.Register("dchat", function(args, ctx)
        if #args < 1 then return { success = false, message = "Usage: dchat <Message>" } end
        local message = table.concat(args, " ")
        Discord.BroadcastToDiscord(message)
        return { success = true, message = "Sent to Discord: " .. message }
    end, "Sends a message to Discord only", {"<Message>"}, "admin")

    CommandRegistry.Register("give", function(args, ctx)
        if #args < 2 then return { success = false, message = "Usage: give <UserId> <ItemId> [Amount]" } end
        local target = GameApi.FindPlayerById(args[1])
        if not target then return { success = false, message = "Player not found: " .. args[1] } end
        local item_id = args[2]
        local amount = tonumber(args[3]) or 1
        GameApi.GiveItem(target, item_id, amount)
        return { success = true, message = string.format("Gave %d x %s to %s", amount, item_id, target:GetPlayerName()) }
    end, "Gives an item to a player", {"<UserId>", "<ItemId>", "[Amount]"}, "admin")

    CommandRegistry.Register("settime", function(args, ctx)
        if #args < 1 then return { success = false, message = "Usage: settime <hour>" } end
        local hour = tonumber(args[1])
        if not hour or hour < 0 or hour > 23 then
            return { success = false, message = "Invalid hour (0-23)" }
        end
        GameApi.SetTime(hour)
        return { success = true, message = "Set time to hour " .. hour }
    end, "Sets the server time hour", {"<hour>"}, "admin")

    CommandRegistry.Register("spawn", function(args, ctx)
        if #args < 4 then return { success = false, message = "Usage: spawn <CreatureId> <X> <Y> <Z> [Level]" } end
        local creature_id = args[1]
        local x = tonumber(args[2])
        local y = tonumber(args[3])
        local z = tonumber(args[4])
        local level = tonumber(args[5]) or 1
        if not x or not y or not z then return { success = false, message = "Invalid coordinates" } end
        GameApi.SpawnCreature(creature_id, x, y, z, level)
        return { success = true, message = string.format("Spawned %s at %.1f %.1f %.1f (level %d)", creature_id, x, y, z, level) }
    end, "Spawns a creature at coordinates", {"<CreatureId>", "<X>", "<Y>", "<Z>", "[Level]"}, "admin")

    CommandRegistry.Register("kill", function(args, ctx)
        if #args < 1 then return { success = false, message = "Usage: kill <UserId>" } end
        local target = GameApi.FindPlayerById(args[1])
        if not target then return { success = false, message = "Player not found: " .. args[1] } end
        local character = GameApi.GetPlayerCharacter(target)
        if not character then return { success = false, message = "Could not find character" } end
        ExecuteInGameThread(function()
            character:ReceiveDamage(999999, nil, nil)
        end)
        return { success = true, message = "Killed player " .. target:GetPlayerName() }
    end, "Kills a player", {"<UserId>"}, "admin")

    CommandRegistry.Register("heal", function(args, ctx)
        if #args < 1 then return { success = false, message = "Usage: heal <UserId>" } end
        local target = GameApi.FindPlayerById(args[1])
        if not target then return { success = false, message = "Player not found: " .. args[1] } end
        local character = GameApi.GetPlayerCharacter(target)
        if not character then return { success = false, message = "Could not find character" } end
        ExecuteInGameThread(function()
            if character.Heal then
                character:Heal(999999)
            elseif character.SetHealth then
                character:SetHealth(100)
            end
        end)
        return { success = true, message = "Healed player " .. target:GetPlayerName() }
    end, "Heals a player", {"<UserId>"}, "admin")

    CommandRegistry.Register("version", function(args, ctx)
        return { success = true, message = "WindroseRCON 1.0.0" }
    end, "Shows the mod version", {}, "any")
end

return Commands
