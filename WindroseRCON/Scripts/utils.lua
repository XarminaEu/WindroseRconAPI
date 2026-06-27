local Utils = {}

local log_levels = { debug = 1, info = 2, warn = 3, error = 4 }

Utils.Config = nil

function Utils.SetConfig(config)
    Utils.Config = config
end

function Utils.Log(level, message)
    if not Utils.Config then return end
    local current_level = log_levels[Utils.Config.general.log_level] or 2
    if log_levels[level] >= current_level then
        print(string.format("[WindroseRCON] [%s] %s\n", level:upper(), message))
    end
end

function Utils.LogDebug(message) Utils.Log("debug", message) end
function Utils.LogInfo(message) Utils.Log("info", message) end
function Utils.LogWarn(message) Utils.Log("warn", message) end
function Utils.LogError(message) Utils.Log("error", message) end

function Utils.SplitString(input, separator)
    separator = separator or "%s"
    local result = {}
    for match in string.gmatch(input, "([^" .. separator .. "]+)") do
        table.insert(result, match)
    end
    return result
end

function Utils.Trim(s)
    return s:match("^%s*(.-)%s*$")
end

function Utils.QuoteAwareSplit(input)
    local result = {}
    local current = ""
    local in_quotes = false
    for i = 1, #input do
        local char = input:sub(i, i)
        if char == '"' then
            in_quotes = not in_quotes
        elseif char == ' ' and not in_quotes then
            if #current > 0 then
                table.insert(result, current)
                current = ""
            end
        else
            current = current .. char
        end
    end
    if #current > 0 then
        table.insert(result, current)
    end
    return result
end

function Utils.FileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

function Utils.ReadFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

function Utils.WriteFile(path, content)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

function Utils.AppendFile(path, content)
    local file = io.open(path, "a")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

function Utils.IsAdmin(user_id, config)
    if not user_id or not config then return false end
    for _, id in ipairs(config.admin.steam_ids or {}) do
        if user_id:find(id, 1, true) then
            return true
        end
    end
    return false
end

return Utils
