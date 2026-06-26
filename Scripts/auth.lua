local Auth = {}

local Utils = require("utils")

-- Session-based authenticated tokens.
-- Keys are opaque session IDs (e.g., "console", "file", socket handle).
local authenticated_sessions = {}

function Auth.Init(config)
    Auth.Config = config
end

function Auth.SetAuthenticated(session_id)
    authenticated_sessions[tostring(session_id)] = true
end

function Auth.IsAuthenticated(session_id)
    return authenticated_sessions[tostring(session_id)] == true
end

function Auth.ClearSession(session_id)
    authenticated_sessions[tostring(session_id)] = nil
end

function Auth.CheckPassword(password)
    local expected = Auth.Config and Auth.Config.admin.password
    if not expected or expected == "" then
        return false
    end
    return password == expected
end

function Auth.RequireAdmin(session_id, source)
    if Auth.IsAuthenticated(session_id) then
        return true
    end

    -- RCON source is authenticated separately by the RCON protocol.
    if source == "rcon" then
        return true
    end

    return false, "Admin authentication required. Use: login <password>"
end

function Auth.HandleLogin(session_id, args)
    if #args < 1 then
        return { success = false, message = "Usage: login <password>" }
    end
    local password = args[1]
    if Auth.CheckPassword(password) then
        Auth.SetAuthenticated(session_id)
        Utils.LogInfo("Session authenticated: " .. tostring(session_id))
        return { success = true, message = "Authenticated." }
    else
        Auth.ClearSession(session_id)
        Utils.LogWarn("Failed authentication attempt for session: " .. tostring(session_id))
        return { success = false, message = "Invalid password." }
    end
end

return Auth
