local Json = {}

local function json_encode(value)
    if value == nil then return "null" end
    if type(value) == "boolean" then return value and "true" or "false" end
    if type(value) == "number" then
        if value ~= value then return "null" end
        if value == math.huge then return "null" end
        if value == -math.huge then return "null" end
        return tostring(value)
    end
    if type(value) == "string" then
        local escaped = value:gsub('\\', '\\\\')
                             :gsub('"', '\\"')
                             :gsub('\b', '\\b')
                             :gsub('\f', '\\f')
                             :gsub('\n', '\\n')
                             :gsub('\r', '\\r')
                             :gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    end
    if type(value) == "table" then
        local is_array = true
        local max_index = 0
        for k, _ in pairs(value) do
            if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
                is_array = false
            else
                if k > max_index then max_index = k end
            end
        end
        if is_array and max_index == #value then
            local parts = {}
            for _, v in ipairs(value) do
                table.insert(parts, json_encode(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(value) do
                table.insert(parts, json_encode(tostring(k)) .. ":" .. json_encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return '"' .. tostring(value) .. '"'
end
Json.Encode = json_encode

local function parse_string(str, pos)
    pos = pos + 1
    local result = {}
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then
            return table.concat(result), pos + 1
        elseif c == '\\' then
            pos = pos + 1
            if pos > #str then return nil, pos end
            local esc = str:sub(pos, pos)
            if esc == '"' then table.insert(result, '"')
            elseif esc == '\\' then table.insert(result, '\\')
            elseif esc == '/' then table.insert(result, '/')
            elseif esc == 'b' then table.insert(result, '\b')
            elseif esc == 'f' then table.insert(result, '\f')
            elseif esc == 'n' then table.insert(result, '\n')
            elseif esc == 'r' then table.insert(result, '\r')
            elseif esc == 't' then table.insert(result, '\t')
            elseif esc == 'u' then
                if pos + 4 > #str then return nil, pos end
                local hex = str:sub(pos + 1, pos + 4)
                local code = tonumber(hex, 16)
                if not code then return nil, pos end
                table.insert(result, utf8.char(code))
                pos = pos + 4
            else
                table.insert(result, esc)
            end
        else
            table.insert(result, c)
        end
        pos = pos + 1
    end
    return nil, pos
end

local function skip_whitespace(str, pos)
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end
    return pos
end

local parse_value

local function parse_object(str, pos)
    local obj = {}
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    if pos <= #str and str:sub(pos, pos) == '}' then
        return obj, pos + 1
    end
    while true do
        pos = skip_whitespace(str, pos)
        if pos > #str or str:sub(pos, pos) ~= '"' then return nil, pos end
        local key, new_pos = parse_string(str, pos)
        if not key then return nil, new_pos end
        pos = skip_whitespace(str, new_pos)
        if pos > #str or str:sub(pos, pos) ~= ':' then return nil, pos end
        pos = skip_whitespace(str, pos + 1)
        local val, val_pos = parse_value(str, pos)
        if val == nil and val_pos == pos then return nil, pos end
        obj[key] = val
        pos = skip_whitespace(str, val_pos)
        if pos > #str then return nil, pos end
        local c = str:sub(pos, pos)
        if c == '}' then return obj, pos + 1 end
        if c ~= ',' then return nil, pos end
        pos = pos + 1
    end
end

local function parse_array(str, pos)
    local arr = {}
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    if pos <= #str and str:sub(pos, pos) == ']' then
        return arr, pos + 1
    end
    while true do
        pos = skip_whitespace(str, pos)
        local val, val_pos = parse_value(str, pos)
        if val == nil and val_pos == pos then return nil, pos end
        table.insert(arr, val)
        pos = skip_whitespace(str, val_pos)
        if pos > #str then return nil, pos end
        local c = str:sub(pos, pos)
        if c == ']' then return arr, pos + 1 end
        if c ~= ',' then return nil, pos end
        pos = pos + 1
    end
end

local function parse_number(str, pos)
    local start_pos = pos
    if str:sub(pos, pos) == '-' then pos = pos + 1 end
    while pos <= #str and str:sub(pos, pos):match("%d") do pos = pos + 1 end
    if pos <= #str and str:sub(pos, pos) == '.' then
        pos = pos + 1
        while pos <= #str and str:sub(pos, pos):match("%d") do pos = pos + 1 end
    end
    if pos <= #str and str:sub(pos, pos):match("[eE]") then
        pos = pos + 1
        if pos <= #str and str:sub(pos, pos):match("[+-]") then pos = pos + 1 end
        while pos <= #str and str:sub(pos, pos):match("%d") do pos = pos + 1 end
    end
    local num_str = str:sub(start_pos, pos - 1)
    local num = tonumber(num_str)
    if not num then return nil, start_pos end
    return num, pos
end

parse_value = function(str, pos)
    pos = skip_whitespace(str, pos)
    if pos > #str then return nil, pos end
    local c = str:sub(pos, pos)
    if c == '{' then return parse_object(str, pos)
    elseif c == '[' then return parse_array(str, pos)
    elseif c == '"' then return parse_string(str, pos)
    elseif c == 't' then
        if str:sub(pos, pos + 3) == "true" then return true, pos + 4 end
        return nil, pos
    elseif c == 'f' then
        if str:sub(pos, pos + 4) == "false" then return false, pos + 5 end
        return nil, pos
    elseif c == 'n' then
        if str:sub(pos, pos + 3) == "null" then return nil, pos + 4 end
        return nil, pos
    elseif c:match("[%-%d]") then
        return parse_number(str, pos)
    else
        return nil, pos
    end
end

function Json.Decode(str)
    if not str or str == "" then return nil end
    local result, pos = parse_value(str, 1)
    if result == nil and pos == 1 then return nil end
    pos = skip_whitespace(str, pos)
    if pos <= #str then return nil end
    return result
end

return Json
