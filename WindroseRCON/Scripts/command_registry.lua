local CommandRegistry = {}
local Commands = {}

local Auth = require("auth")

function CommandRegistry.Register(name, handler, description, args, permission)
    Commands[name:lower()] = {
        handler = handler,
        description = description or "No description",
        args = args or {},
        permission = permission or "admin",
    }
end

function CommandRegistry.Get(name)
    return Commands[name:lower()]
end

function CommandRegistry.GetAll()
    local result = {}
    for name, cmd in pairs(Commands) do
        result[name] = cmd
    end
    return result
end

function CommandRegistry.Execute(name, args, ctx)
    local cmd = CommandRegistry.Get(name)
    if not cmd then
        return { success = false, message = "Unknown command: " .. name }
    end

    local session_id = ctx and ctx.session_id or "default"
    local source = ctx and ctx.source or "unknown"

    if cmd.permission == "admin" then
        local ok, err = Auth.RequireAdmin(session_id, source)
        if not ok then
            return { success = false, message = err }
        end
    end

    local ok, result = pcall(function()
        return cmd.handler(args, ctx)
    end)
    if not ok then
        return { success = false, message = "Command error: " .. tostring(result) }
    end

    if result == nil then
        return { success = true, message = "OK" }
    end
    return result
end

return CommandRegistry
