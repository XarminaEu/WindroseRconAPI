print("[WindroseRCON] Loading...\n")

local Config = require("config")
local Utils = require("utils")
local CommandRegistry = require("command_registry")
local Commands = require("commands")
local GameApi = require("game_api")
local Auth = require("auth")
local RconServer = require("rcon_server")
local RestApi = require("rest_api")
local HttpServer = require("http_server")
local Discord = require("discord")

local config = Config.Load()
Utils.SetConfig(config)
Auth.Init(config)

-- If no separate RCON password is set, use the admin password for RCON too.
if not config.rcon.password or config.rcon.password == "" then
    config.rcon.password = config.admin.password
end

Commands.RegisterAll()

local function ProcessCommandFile()
    if not config.rcon.fallback_file_bridge then return end

    local cmd_file = config.rcon.command_file
    local resp_file = config.rcon.response_file

    if not Utils.FileExists(cmd_file) then return end

    local content = Utils.ReadFile(cmd_file)
    if not content or content == "" then return end

    Utils.WriteFile(cmd_file, "")

    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local responses = {}
    for _, line in ipairs(lines) do
        local parts = Utils.SplitString(line, "|")
        if #parts >= 2 then
            local req_id = parts[1]
            local cmd_name = parts[2]:lower()
            local args = {}
            for i = 3, #parts do
                table.insert(args, parts[i])
            end

            Utils.LogInfo("Executing file-bridge command: " .. cmd_name .. " (id=" .. req_id .. ")")

            local result = CommandRegistry.Execute(cmd_name, args, { config = config, source = "file", session_id = "file" })
            local response_line = string.format("%s|%d|%s", req_id, result.success and 1 or 0, result.message or "")
            table.insert(responses, response_line)
        end
    end

    if #responses > 0 then
        local existing = Utils.ReadFile(resp_file) or ""
        Utils.WriteFile(resp_file, existing .. table.concat(responses, "\n") .. "\n")
    end
end

local function ProcessConsoleCommand(full_command, parameters, output_device)
    local cmd_name = parameters[1]
    if not cmd_name then return false end

    -- UE4SS sometimes passes the command name as the first parameter, sometimes not.
    if cmd_name == "wrc" or cmd_name == "windrose" then
        table.remove(parameters, 1)
        cmd_name = parameters[1]
    end
    if not cmd_name then return false end

    local session_id = "console"
    if output_device and output_device:IsValid() and output_device.GetName then
        local ok, name = pcall(function() return output_device:GetName() end)
        if ok then session_id = tostring(name) or "console" end
    end
    local result = CommandRegistry.Execute(cmd_name, parameters, { config = config, source = "console", session_id = session_id })
    local message = result.message or "OK"
    if output_device and output_device:IsValid() then
        local ok, err = pcall(function() output_device:Log(message) end)
        if not ok then
            print("[WindroseRCON] [Console] " .. message)
        end
    else
        print("[WindroseRCON] [Console] " .. message)
    end
    return true
end

RegisterConsoleCommandHandler("wrc", function(FullCommand, Parameters, Ar)
    return ProcessConsoleCommand(FullCommand, Parameters, Ar)
end)

RegisterConsoleCommandHandler("windrose", function(FullCommand, Parameters, Ar)
    return ProcessConsoleCommand(FullCommand, Parameters, Ar)
end)

Utils.LogInfo("Console commands registered: wrc, windrose")

local rcon_started = RconServer.Start(config)
if not rcon_started then
    Utils.LogWarn("In-process RCON server failed to start. File bridge still active if enabled.")
end

Discord.Init(config)

local rest_api_started = RestApi.Start(config, CommandRegistry, Auth)
if not rest_api_started then
    Utils.LogWarn("REST API server failed to start.")
end

function Tick()
    local ok1, err1 = pcall(ProcessCommandFile)
    if not ok1 then
        Utils.LogError("Tick poll error: " .. tostring(err1))
    end
    local ok2, err2 = pcall(function()
        HttpServer.TickNow(config, CommandRegistry, Auth)
    end)
    if not ok2 then
        Utils.LogError("HTTP tick error: " .. tostring(err2))
    end
    local ok3, err3 = pcall(function()
        RconServer.TickNow()
    end)
    if not ok3 then
        Utils.LogError("RCON tick error: " .. tostring(err3))
    end
end

local function TryChatHook(class_name, method_name)
    local full_name = class_name .. ":" .. method_name
    local ok = pcall(function()
        RegisterHook(full_name, function(Context)
            local params = Context:get_params()
            if params and params[1] then
                local message = tostring(params[1])
                local sender = "Unknown"
                if params[2] then
                    sender = tostring(params[2])
                end
                Discord.SendMessage("[" .. sender .. "]: " .. message)
            end
        end)
    end)
    if ok then
        Utils.LogInfo("Chat hook registered: " .. full_name)
        return true
    else
        Utils.LogDebug("Chat hook failed: " .. full_name)
        return false
    end
end

if config.discord and config.discord.webhook_url ~= "" then
    local hooked = TryChatHook("/Script/R5.R5PlayerController", "ServerSay") or
                   TryChatHook("/Script/R5.R5PlayerState", "ServerSay") or
                   TryChatHook("/Script/R5.R5GameState", "BroadcastChatMessage")
    if not hooked then
        Utils.LogWarn("Could not auto-register in-game chat hook. Discord will still receive messages from broadcast/say commands and manual dchat command.")
    end
end

Utils.LogInfo("WindroseRCON loaded. Commands available via 'wrc <command>' or RCON.")
