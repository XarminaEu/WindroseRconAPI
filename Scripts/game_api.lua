local GameApi = {}

-- Known Windrose class names (R5 prefix). These may change with game updates.
GameApi.Classes = {
    Character = "R5Character",
    PlayerState = "R5PlayerState",
    GameState = "R5GameState",
    GameMode = "R5GameMode",
    PlayerController = "R5PlayerController",
}

local BannedFlags = 0
if type(EObjectFlags) == "table" then
    BannedFlags = EObjectFlags.RF_ClassDefaultObject | EObjectFlags.RF_ArchetypeObject
end

function GameApi.GetGameState()
    local game_states = FindObjects(nil, GameApi.Classes.GameState, nil, nil, BannedFlags, false)
    if game_states and #game_states > 0 then
        return game_states[1]
    end
    return nil
end

function GameApi.GetGameMode()
    local game_modes = FindObjects(nil, GameApi.Classes.GameMode, nil, nil, BannedFlags, false)
    if game_modes and #game_modes > 0 then
        return game_modes[1]
    end
    return nil
end

function GameApi.GetAllPlayerStates()
    local game_state = GameApi.GetGameState()
    if not game_state or not game_state:IsValid() then
        return {}
    end

    local player_array = game_state.PlayerArray
    if not player_array then
        return {}
    end

    local result = {}
    local count = player_array:GetArrayNum()
    for i = 0, count - 1 do
        local player_state = player_array:Get(i)
        if player_state and player_state:IsValid() then
            table.insert(result, player_state)
        end
    end
    return result
end

function GameApi.FindPlayerById(user_id)
    if not user_id or user_id == "" then return nil end
    local players = GameApi.GetAllPlayerStates()
    for _, player_state in ipairs(players) do
        local player_name = player_state:GetPlayerName() or ""
        local player_id = tostring(player_state.PlayerId or "")
        local steam_id = ""
        local controller = player_state:GetOwner()
        if controller and controller:IsValid() then
            local steam_id_prop = controller:Reflection():GetProperty("SteamId")
            if steam_id_prop then
                steam_id = tostring(steam_id_prop:GetPropertyValue(controller) or "")
            end
        end

        local match = user_id == player_name or user_id == player_id or user_id == steam_id
        if not match and (player_name:lower() == user_id:lower() or steam_id:find(user_id, 1, true)) then
            match = true
        end
        if match then
            return player_state
        end
    end
    return nil
end

function GameApi.GetPlayerCharacter(player_state)
    if not player_state or not player_state:IsValid() then return nil end
    local controller = player_state:GetOwner()
    if not controller or not controller:IsValid() then return nil end
    local pawn = controller.Pawn
    if pawn and pawn:IsValid() and pawn:IsA(GameApi.Classes.Character) then
        return pawn
    end
    return nil
end

function GameApi.GetPlayerPosition(player_state)
    local character = GameApi.GetPlayerCharacter(player_state)
    if not character or not character:IsValid() then return nil end
    local location = character:K2_GetActorLocation()
    return { X = location.X, Y = location.Y, Z = location.Z }
end

function GameApi.SetPlayerPosition(player_state, x, y, z)
    local character = GameApi.GetPlayerCharacter(player_state)
    if not character or not character:IsValid() then return false end
    ExecuteInGameThread(function()
        character:K2_SetActorLocation({ X = x, Y = y, Z = z }, false, nil, false)
    end)
    return true
end

function GameApi.KickPlayer(player_state, reason)
    if not player_state or not player_state:IsValid() then return false end
    local controller = player_state:GetOwner()
    if not controller or not controller:IsValid() then return false end
    ExecuteInGameThread(function()
        local game_mode = GameApi.GetGameMode()
        if game_mode and game_mode:IsValid() then
            game_mode:KickPlayer(controller, reason or "Kicked by admin")
        else
            controller:ConsoleCommand("disconnect", true)
        end
    end)
    return true
end

function GameApi.BroadcastMessage(message)
    ExecuteInGameThread(function()
        local game_state = GameApi.GetGameState()
        if game_state and game_state:IsValid() and game_state.BroadcastChatMessage then
            game_state:BroadcastChatMessage(message)
        else
            local players = GameApi.GetAllPlayerStates()
            for _, player_state in ipairs(players) do
                local controller = player_state:GetOwner()
                if controller and controller:IsValid() then
                    controller:ClientMessage(message, "Event", 5.0)
                end
            end
        end
    end)
    return true
end

function GameApi.SendPlayerMessage(player_state, message, message_type)
    if not player_state or not player_state:IsValid() then return false end
    local controller = player_state:GetOwner()
    if not controller or not controller:IsValid() then return false end
    ExecuteInGameThread(function()
        controller:ClientMessage(message, message_type or "Say", 5.0)
    end)
    return true
end

function GameApi.GiveItem(player_state, item_id, amount)
    if not player_state or not player_state:IsValid() then return false end
    local controller = player_state:GetOwner()
    if not controller or not controller:IsValid() then return false end
    ExecuteInGameThread(function()
        local command = string.format("GiveItem %s %d", item_id, amount or 1)
        controller:ConsoleCommand(command, true)
    end)
    return true
end

function GameApi.SpawnCreature(creature_id, x, y, z, level)
    ExecuteInGameThread(function()
        local command = string.format("SpawnCreature %s %f %f %f %d", creature_id, x, y, z, level or 1)
        local game_state = GameApi.GetGameState()
        if game_state and game_state:IsValid() then
            game_state:GetWorld():ExecWorldSpaceSubsystemAction(command)
        end
    end)
    return true
end

function GameApi.SetTime(hour)
    ExecuteInGameThread(function()
        local game_state = GameApi.GetGameState()
        if game_state and game_state:IsValid() and game_state.SetServerTime then
            game_state:SetServerTime(hour)
        end
    end)
    return true
end

return GameApi
