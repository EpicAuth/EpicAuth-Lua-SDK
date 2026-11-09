local JSON = {}

local candidates = { "cjson", "cjson.safe", "dkjson", "lunajson", "json" }
for _, name in ipairs(candidates) do
    local ok, mod = pcall(require, name)
    if ok and type(mod) == "table" and (mod.decode or mod.parse) then
        JSON.decode = mod.decode or mod.parse
        JSON.encode = mod.encode or mod.stringify
        return JSON
    end
end

local function skip_whitespace(str, idx)
    local len = #str
    while idx <= len do
        local b = str:byte(idx)
        if b == 32 or b == 9 or b == 10 or b == 13 then
            idx = idx + 1
        else
            break
        end
    end
    return idx
end

local parse_value

local function parse_string(str, idx)
    idx = idx + 1
    local res = {}
    local len = #str
    while idx <= len do
        local c = str:sub(idx, idx)
        if c == '"' then
            return table.concat(res), idx + 1
        elseif c == "\\" then
            idx = idx + 1
            local esc = str:sub(idx, idx)
            if esc == '"' or esc == "\\" or esc == "/" then
                table.insert(res, esc)
            elseif esc == "b" then table.insert(res, "\b")
            elseif esc == "f" then table.insert(res, "\f")
            elseif esc == "n" then table.insert(res, "\n")
            elseif esc == "r" then table.insert(res, "\r")
            elseif esc == "t" then table.insert(res, "\t")
            elseif esc == "u" then
                local hex = str:sub(idx + 1, idx + 4)
                local code = tonumber(hex, 16)
                if code then
                    if code < 128 then
                        table.insert(res, string.char(code))
                    elseif code < 2048 then
                        table.insert(res, string.char(192 + math.floor(code / 64), 128 + (code % 64)))
                    else
                        table.insert(res, string.char(224 + math.floor(code / 4096), 128 + (math.floor(code / 64) % 64), 128 + (code % 64)))
                    end
                    idx = idx + 4
                else
                    table.insert(res, "u" .. hex)
                    idx = idx + 4
                end
            else
                table.insert(res, esc)
            end
            idx = idx + 1
        else
            table.insert(res, c)
            idx = idx + 1
        end
    end
    return table.concat(res), idx
end

local function parse_number(str, idx)
    local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", idx)
    if num_str then
        return tonumber(num_str), idx + #num_str
    end
    return 0, idx + 1
end

local function parse_array(str, idx)
    idx = idx + 1
    local arr = {}
    idx = skip_whitespace(str, idx)
    if str:sub(idx, idx) == "]" then return arr, idx + 1 end
    local len = #str
    while idx <= len do
        local val
        val, idx = parse_value(str, idx)
        table.insert(arr, val)
        idx = skip_whitespace(str, idx)
        local c = str:sub(idx, idx)
        if c == "]" then return arr, idx + 1
        elseif c == "," then idx = skip_whitespace(str, idx + 1)
        else break end
    end
    return arr, idx
end

local function parse_object(str, idx)
    idx = idx + 1
    local obj = {}
    idx = skip_whitespace(str, idx)
    if str:sub(idx, idx) == "}" then return obj, idx + 1 end
    local len = #str
    while idx <= len do
        idx = skip_whitespace(str, idx)
        if str:sub(idx, idx) ~= '"' then break end
        local key
        key, idx = parse_string(str, idx)
        idx = skip_whitespace(str, idx)
        if str:sub(idx, idx) == ":" then
            idx = skip_whitespace(str, idx + 1)
        end
        local val
        val, idx = parse_value(str, idx)
        obj[key] = val
        idx = skip_whitespace(str, idx)
        local c = str:sub(idx, idx)
        if c == "}" then return obj, idx + 1
        elseif c == "," then idx = skip_whitespace(str, idx + 1)
        else break end
    end
    return obj, idx
end

parse_value = function(str, idx)
    idx = skip_whitespace(str, idx)
    local c = str:sub(idx, idx)
    if c == "{" then return parse_object(str, idx)
    elseif c == "[" then return parse_array(str, idx)
    elseif c == '"' then return parse_string(str, idx)
    elseif c == "t" and str:sub(idx, idx + 3) == "true" then return true, idx + 4
    elseif c == "f" and str:sub(idx, idx + 4) == "false" then return false, idx + 5
    elseif c == "n" and str:sub(idx, idx + 3) == "null" then return nil, idx + 4
    else return parse_number(str, idx) end
end

function JSON.decode(str)
    if type(str) ~= "string" or #str == 0 then return nil end
    return (parse_value(str, 1))
end

function JSON.encode(val)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif t == "table" then
        local is_array = true
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then is_array = false end
        end
        if count == 0 then return "{}" end
        local parts = {}
        if is_array then
            for i = 1, count do
                table.insert(parts, JSON.encode(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, JSON.encode(tostring(k)) .. ":" .. JSON.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

return JSON
