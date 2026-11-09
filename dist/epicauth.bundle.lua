--[==[
================================================================================
EpicAuth Lua SDK - Standalone Single-File Distribution Bundle
Version:  1.0.3
Homepage: https://epicauth.cc
License:  Elastic License 2.0

This standalone bundle contains all official EpicAuth SDK modules packaged into
a single zero-dependency file for use in embedded runtimes, game engines
(Roblox, FiveM, GameGuardian), plugin sandboxes, and environments without LuaRocks.

USAGE MODES:
  1. Direct file load (sandboxes):
     local EpicAuth = dofile("epicauth.bundle.lua")
  2. Evaluated load:
     local EpicAuth = loadfile("epicauth.bundle.lua")()
  3. Standard module require (when in package.path):
     local EpicAuth = require("epicauth.bundle")

INITIALIZATION:
  local app = EpicAuth.new({
      name = "YourApplicationName",
      ownerid = "YOUR_OWNER_ID",
      version = "1.0",
      exitOnError = false -- recommended for game servers/sandboxes
  })
  app:init()
================================================================================
--]==]

return (function(...)
    local _ENV = _ENV
    local _G = _G or (_ENV and _ENV._G) or {}
    local _modules = {}
    local _loaded = {}

    -- Custom isolated require wrapper for strict sandboxed runtimes
    local function _custom_require(modname)
        if type(modname) ~= "string" then
            error("module name must be a string", 2)
        end

        local canonical = modname
        if canonical:sub(1, 13) == "src.epicauth." then
            canonical = "epicauth." .. canonical:sub(14)
        elseif canonical == "src.epicauth" or canonical == "epicauth.bundle" then
            canonical = "epicauth"
        end

        if not _modules[canonical] and _modules["epicauth." .. canonical] then
            canonical = "epicauth." .. canonical
        end

        if canonical == "epicauth" then
            canonical = "epicauth.init"
        end

        if _loaded[canonical] ~= nil then
            return _loaded[canonical]
        end

        local loader = _modules[canonical]
        if loader then
            local res = loader(_custom_require, _loaded)
            if res == nil then res = true end
            _loaded[canonical] = res
            return res
        end

        local glob_req = rawget(_G, "require")
        if type(glob_req) == "function" and glob_req ~= _custom_require then
            return glob_req(modname)
        end

        error(string.format("module '%s' not found in EpicAuth bundle", tostring(modname)), 2)
    end

    -- Register module loaders in package.preload if available
    if type(package) == "table" and type(package.preload) == "table" then
        local preload = package.preload
        preload["epicauth"] = function() return _custom_require("epicauth.init") end
        preload["epicauth.bundle"] = function() return _custom_require("epicauth.init") end
        preload["epicauth.init"] = function() return _custom_require("epicauth.init") end
        preload["epicauth.client"] = function() return _custom_require("epicauth.client") end
        preload["epicauth.crypto"] = function() return _custom_require("epicauth.crypto") end
        preload["epicauth.errors"] = function() return _custom_require("epicauth.errors") end
        preload["epicauth.http"] = function() return _custom_require("epicauth.http") end
        preload["epicauth.hwid"] = function() return _custom_require("epicauth.hwid") end
        preload["epicauth.json"] = function() return _custom_require("epicauth.json") end
    end

    ----------------------------------------------------------------------------
    -- Module: epicauth.errors (E:\GitHub\epicauth-org\EpicAuth-Lua-SDK\src\epicauth\errors.lua)
    ----------------------------------------------------------------------------
    _modules["epicauth.errors"] = function(require, _LOADED)
local EpicAuthError = {}
EpicAuthError.__index = EpicAuthError

function EpicAuthError.new(message, status)
    local self = setmetatable({}, EpicAuthError)
    self.name = "EpicAuthError"
    self.message = tostring(message or "EpicAuth error")
    self.status = status
    return self
end

function EpicAuthError:__tostring()
    if self.status then
        return string.format("EpicAuthError (%s): %s", tostring(self.status), self.message)
    end
    return string.format("EpicAuthError: %s", self.message)
end

return EpicAuthError
    end

    ----------------------------------------------------------------------------
    -- Module: epicauth.json (E:\GitHub\epicauth-org\EpicAuth-Lua-SDK\src\epicauth\json.lua)
    ----------------------------------------------------------------------------
    _modules["epicauth.json"] = function(require, _LOADED)
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
    end

    ----------------------------------------------------------------------------
    -- Module: epicauth.crypto (E:\GitHub\epicauth-org\EpicAuth-Lua-SDK\src\epicauth\crypto.lua)
    ----------------------------------------------------------------------------
    _modules["epicauth.crypto"] = function(require, _LOADED)
local crypto = {}

local _bit = (function()
    local floor = math.floor
    local toint = math.tointeger or floor

    local b = rawget(_G, "bit")
    if b and b.band and b.bxor and b.rshift and b.lshift then
        local band, bxor, bnot = b.band, b.bxor, b.bnot
        local rshift, lshift = b.rshift, b.lshift
        local bor = b.bor or function(x, y) return bxor(bxor(x, y), band(x, y)) end
        local ror = b.ror or function(x, n)
            return bor(rshift(x, n), lshift(x, (32 - n) % 32))
        end
        return {
            band = band, bxor = bxor, bnot = bnot, bor = bor,
            rshift = rshift, lshift = lshift, ror = ror,
            to32 = function(x) return toint(band(x, 0xFFFFFFFF)) end
        }
    end

    local ok_load, fn_band = pcall(load, "return function(a, b) return (a & b) & 0xFFFFFFFF end")
    if ok_load and type(fn_band) == "function" then
        local band = fn_band()
        local bxor = load("return function(a, b) return (a ~ b) & 0xFFFFFFFF end")()
        local bor  = load("return function(a, b) return (a | b) & 0xFFFFFFFF end")()
        local bnot = load("return function(a) return (~a) & 0xFFFFFFFF end")()
        local rshift = load("return function(a, n) return (a & 0xFFFFFFFF) >> n end")()
        local lshift = load("return function(a, n) return ((a & 0xFFFFFFFF) << n) & 0xFFFFFFFF end")()
        local ror = load("return function(a, n) local u = a & 0xFFFFFFFF; return ((u >> n) | (u << ((32 - n) & 31))) & 0xFFFFFFFF end")()
        local to32 = load("return function(a) return math.tointeger(a & 0xFFFFFFFF) end")()
        return {
            band = band, bxor = bxor, bnot = bnot, bor = bor,
            rshift = rshift, lshift = lshift, ror = ror,
            to32 = to32
        }
    end

    local b32 = rawget(_G, "bit32")
    if b32 and b32.band and b32.bxor then
        return {
            band = b32.band, bxor = b32.bxor, bnot = b32.bnot, bor = b32.bor,
            rshift = b32.rshift, lshift = b32.lshift,
            ror = b32.rrotate or function(x, n) return b32.bor(b32.rshift(x, n), b32.lshift(x, (32 - n) % 32)) end,
            to32 = function(x) return toint(b32.band(x, 0xFFFFFFFF)) end
        }
    end

    local U32 = 4294967296
    local AND, XOR = {}, {}
    for a = 0, 15 do
        for c = 0, 15 do
            local av, cv, both, diff, place = a, c, 0, 0, 1
            for _ = 1, 4 do
                local x, y = av % 2, cv % 2
                if x == 1 and y == 1 then both = both + place end
                if x ~= y then diff = diff + place end
                av, cv, place = floor(av / 2), floor(cv / 2), place * 2
            end
            AND[a * 16 + c], XOR[a * 16 + c] = both, diff
        end
    end
    local function bitop(a, c, lookup)
        local val, place = 0, 1
        for _ = 1, 8 do
            val = val + lookup[(a % 16) * 16 + c % 16] * place
            a, c, place = floor(a / 16), floor(c / 16), place * 16
        end
        return val
    end
    local function band(a, c) return bitop(a % U32, c % U32, AND) end
    local function bxor(a, c) return bitop(a % U32, c % U32, XOR) end
    local function bor(a, c) return bxor(bxor(a, c), band(a, c)) end
    local function bnot(a) return (U32 - 1 - (a % U32)) end
    local function rshift(a, n) return floor((a % U32) / (2 ^ n)) end
    local function lshift(a, n) return ((a % (2 ^ (32 - n))) * (2 ^ n)) % U32 end
    local function ror(a, n)
        local divisor = 2 ^ n
        local x = a % U32
        return floor(x / divisor) + (x % divisor) * (2 ^ (32 - n))
    end
    return {
        band = band, bxor = bxor, bnot = bnot, bor = bor,
        rshift = rshift, lshift = lshift, ror = ror,
        to32 = function(x) return toint(floor(x) % U32) end
    }
end)()

function crypto.sha256(msg)
    msg = msg or ""
    local band, bxor, bnot = _bit.band, _bit.bxor, _bit.bnot
    local rshift, ror, to32 = _bit.rshift, _bit.ror, _bit.to32

    local K256 = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }

    local len = #msg
    local extra = (55 - (len % 64)) % 64
    local bits = len * 8
    local pad = msg .. string.char(128) .. string.rep(string.char(0), extra)

    local high_bits = math.floor(bits / 4294967296)
    local low_bits = bits % 4294967296
    pad = pad .. string.char(
        math.floor(high_bits / 16777216) % 256,
        math.floor(high_bits / 65536) % 256,
        math.floor(high_bits / 256) % 256,
        high_bits % 256,
        math.floor(low_bits / 16777216) % 256,
        math.floor(low_bits / 65536) % 256,
        math.floor(low_bits / 256) % 256,
        low_bits % 256
    )

    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

    local w = {}
    for chunk = 1, #pad, 64 do
        for i = 0, 15 do
            local p = chunk + i * 4
            local b1, b2, b3, b4 = string.byte(pad, p, p + 3)
            w[i] = to32(b1 * 16777216 + b2 * 65536 + b3 * 256 + b4)
        end
        for i = 16, 63 do
            local v0 = w[i - 15]
            local s0 = bxor(bxor(ror(v0, 7), ror(v0, 18)), rshift(v0, 3))
            local v1 = w[i - 2]
            local s1 = bxor(bxor(ror(v1, 17), ror(v1, 19)), rshift(v1, 10))
            w[i] = to32(w[i - 16] + s0 + w[i - 7] + s1)
        end

        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for i = 0, 63 do
            local s1 = bxor(bxor(ror(e, 6), ror(e, 11)), ror(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = to32(h + s1 + ch + K256[i + 1] + w[i])
            local s0 = bxor(bxor(ror(a, 2), ror(a, 13)), ror(a, 22))
            local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
            local temp2 = to32(s0 + maj)

            h = g
            g = f
            f = e
            e = to32(d + temp1)
            d = c
            c = b
            b = a
            a = to32(temp1 + temp2)
        end

        h0 = to32(h0 + a)
        h1 = to32(h1 + b)
        h2 = to32(h2 + c)
        h3 = to32(h3 + d)
        h4 = to32(h4 + e)
        h5 = to32(h5 + f)
        h6 = to32(h6 + g)
        h7 = to32(h7 + h)
    end

    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4, h5, h6, h7)
end

function crypto.hex_to_bytes(hex)
    if type(hex) ~= "string" then return "" end
    return (hex:gsub("..", function(cc)
        return string.char(tonumber(cc, 16) or 0)
    end))
end

function crypto.verify_signature(signature_hex, message_str, public_key_hex)
    local ok_mono, monocypher = pcall(require, "monocypher")
    if ok_mono and monocypher and monocypher.check then
        local sig_bytes = crypto.hex_to_bytes(signature_hex)
        local pk_bytes = crypto.hex_to_bytes(public_key_hex)
        return monocypher.check(sig_bytes, pk_bytes, message_str)
    end

    local ok_sodium, sodium = pcall(require, "luasodium")
    if ok_sodium and sodium and sodium.crypto_sign and sodium.crypto_sign.verify_detached then
        local sig_bytes = crypto.hex_to_bytes(signature_hex)
        local pk_bytes = crypto.hex_to_bytes(public_key_hex)
        return sodium.crypto_sign.verify_detached(sig_bytes, message_str, pk_bytes)
    end

    local ok_nacl, nacl = pcall(require, "tweetnacl")
    if ok_nacl and nacl and nacl.sign_open then
        local sig_bytes = crypto.hex_to_bytes(signature_hex)
        local pk_bytes = crypto.hex_to_bytes(public_key_hex)
        local combined = sig_bytes .. message_str
        local opened = nacl.sign_open(combined, pk_bytes)
        return opened ~= nil
    end

    return nil, "No Ed25519 library available"
end

return crypto
    end

    ----------------------------------------------------------------------------
    -- Module: epicauth.hwid (E:\GitHub\epicauth-org\EpicAuth-Lua-SDK\src\epicauth\hwid.lua)
    ----------------------------------------------------------------------------
    _modules["epicauth.hwid"] = function(require, _LOADED)
local hwid = {}

local function load_internal(name)
    local ok, mod = pcall(require, "epicauth." .. name)
    if ok then return mod end
    ok, mod = pcall(require, "src.epicauth." .. name)
    if ok then return mod end
    return require(name)
end

local crypto = load_internal("crypto")

function hwid.get(custom_override)
    if type(custom_override) == "function" then
        local ok, val = pcall(custom_override)
        if ok and val and tostring(val) ~= "" then
            return tostring(val)
        end
    elseif (type(custom_override) == "string" or type(custom_override) == "number") and #tostring(custom_override) > 0 then
        return tostring(custom_override)
    end

    local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
        or (os and type(os.getenv) == "function" and (os.getenv("OS") or ""):find("Windows") ~= nil)

    if is_windows and io and type(io.popen) == "function" then
        local ok, p = pcall(io.popen, 'reg query "HKLM\\SOFTWARE\\Microsoft\\Cryptography" /v MachineGuid 2>nul')
        if ok and p then
            local out = p:read("*a")
            p:close()
            local guid = out and out:match("MachineGuid%s+REG_SZ%s+([%w%-]+)")
            if guid and #guid > 5 then
                return guid
            end
        end

        local username = (os and type(os.getenv) == "function" and os.getenv("USERNAME")) or ""
        if #username > 0 then
            local ok_sid, p_sid = pcall(io.popen, string.format('wmic useraccount where name="%s" get sid 2>nul', username))
            if ok_sid and p_sid then
                local sid_out = p_sid:read("*a")
                p_sid:close()
                local sid = sid_out and sid_out:match("(S%-%d%-[%d%-]+)")
                if sid and #sid > 10 then
                    return sid
                end
            end
        end
    end

    if not is_windows and io and type(io.open) == "function" then
        local f = io.open("/etc/machine-id", "r") or io.open("/var/lib/dbus/machine-id", "r")
        if f then
            local mid = f:read("*a")
            f:close()
            mid = mid and mid:gsub("%s+", "")
            if mid and #mid > 10 then
                return mid
            end
        end

        if type(io.popen) == "function" then
            local ok, p = pcall(io.popen, "ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | grep IOPlatformSerialNumber")
            if ok and p then
                local out = p:read("*a")
                p:close()
                local serial = out and out:match('"IOPlatformSerialNumber"%s*=%s*"([^"]+)"')
                if serial and #serial > 0 then
                    return serial
                end
            end
        end
    end

    local getenv = (os and type(os.getenv) == "function" and os.getenv) or function() return nil end
    local ostime = (os and type(os.time) == "function" and os.time) or function() return 0 end
    local fallback = table.concat({
        getenv("COMPUTERNAME") or getenv("HOSTNAME") or "DEVICE",
        getenv("USERNAME") or getenv("USER") or "USER",
        getenv("PROCESSOR_ARCHITECTURE") or getenv("HOSTTYPE") or "ARCH",
        getenv("PROCESSOR_IDENTIFIER") or getenv("OS") or "GENERIC",
        tostring(ostime())
    }, "|")

    return crypto.sha256(fallback):sub(1, 32)
end

return hwid
    end

    ----------------------------------------------------------------------------
    -- Module: epicauth.http (E:\GitHub\epicauth-org\EpicAuth-Lua-SDK\src\epicauth\http.lua)
    ----------------------------------------------------------------------------
    _modules["epicauth.http"] = function(require, _LOADED)
local http = {}

function http.url_encode(str)
    if type(str) ~= "string" then str = tostring(str) end
    return (str:gsub("[^%w%-%._~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

function http.build_query(params)
    local parts = {}
    for k, v in pairs(params) do
        if v ~= nil then
            table.insert(parts, http.url_encode(tostring(k)) .. "=" .. http.url_encode(tostring(v)))
        end
    end
    return table.concat(parts, "&")
end

local function normalize_headers(raw_h)
    local h = {}
    if type(raw_h) == "table" then
        for k, v in pairs(raw_h) do
            local val = type(v) == "table" and v[1] or v
            h[tostring(k):lower()] = tostring(val)
        end
    end
    return h
end

function http.post(url, post_data_str, custom_handler)
    if type(custom_handler) == "function" then
        local headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }
        local ok, res, opt2, opt3 = pcall(custom_handler, url, headers, post_data_str)
        if not ok or res == nil then
            local ok2, res2, opt2_2, opt3_2 = pcall(custom_handler, {
                url = url,
                method = "POST",
                headers = headers,
                body = post_data_str
            })
            if ok2 and res2 ~= nil then
                ok, res, opt2, opt3 = ok2, res2, opt2_2, opt3_2
            end
        end

        if not ok then
            error("Custom http_handler failed: " .. tostring(res))
        end

        if type(res) == "string" then
            local status_code = tonumber(opt2) or (type(opt2) == "table" and tonumber(opt3)) or 200
            local raw_h = (type(opt2) == "table" and opt2) or (type(opt3) == "table" and opt3) or {}
            return {
                status = status_code,
                body = res,
                headers = normalize_headers(raw_h)
            }
        elseif type(res) == "table" then
            local status_code = tonumber(res.status or res.statusCode or res.StatusCode or res.code or res.status_code) or 200
            local body_str = tostring(res.body or res.Body or res.content or res.text or "")
            local raw_h = res.headers or res.Headers or {}
            return {
                status = status_code,
                body = body_str,
                headers = normalize_headers(raw_h)
            }
        end
        return res
    end

    local game_obj = rawget(_G, "game")
    if type(game_obj) == "userdata" or type(game_obj) == "table" then
        local ok, http_svc = pcall(function() return game_obj:GetService("HttpService") end)
        if ok and http_svc and http_svc.RequestAsync then
            local resp = http_svc:RequestAsync({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
                Body = post_data_str
            })
            local h = normalize_headers(resp.Headers)
            return { status = resp.StatusCode or 200, body = resp.Body or "", headers = h }
        end
    end

    local gg = rawget(_G, "gg")
    if type(gg) == "table" and type(gg.makeRequest) == "function" then
        local res = gg.makeRequest(url, { ["Content-Type"] = "application/x-www-form-urlencoded" }, post_data_str)
        if res then
            return {
                status = tonumber(res.code) or 200,
                body = res.content or "",
                headers = normalize_headers(res.headers)
            }
        end
    end

    local has_ssl, https = pcall(require, "ssl.https")
    local has_ltn12, ltn12 = pcall(require, "ltn12")
    if has_ssl and has_ltn12 and type(https.request) == "function" then
        local resp_body = {}
        local _, code, resp_headers = https.request({
            url = url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["Content-Length"] = tostring(#post_data_str)
            },
            source = ltn12.source.string(post_data_str),
            sink = ltn12.sink.table(resp_body)
        })
        return { status = tonumber(code) or 200, body = table.concat(resp_body), headers = normalize_headers(resp_headers) }
    end

    if io and type(io.popen) == "function" and type(io.open) == "function" then
        local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
            or (os and type(os.getenv) == "function" and (os.getenv("OS") or ""):find("Windows") ~= nil)
        local tmp_dir = (os and type(os.getenv) == "function" and (os.getenv("TEMP") or os.getenv("TMP"))) or (is_windows and "." or "/tmp")
        local ostime = (os and type(os.time) == "function" and os.time()) or 0
        local tmp_file = string.format("%s/epicauth_%d_%d.tmp", tmp_dir, ostime, math.random(1000, 9999))
        local f = io.open(tmp_file, "wb")
        if f then
            f:write(post_data_str)
            f:close()
        end

        local cmd = string.format('curl -s -i -X POST "%s" --data-binary "@%s"', url, tmp_file)
        if is_windows then
            cmd = string.format('curl.exe -s -i -X POST "%s" --data-binary "@%s"', url, tmp_file)
        end

        local handle = io.popen(cmd, "r")
        if handle then
            local raw = handle:read("*a")
            handle:close()
            pcall(os.remove, tmp_file)

            if raw and #raw > 0 then
                local header_part, body_part = raw:match("^(.-)\r?\n\r?\n(.*)$")
                if not header_part then
                    header_part = ""
                    body_part = raw
                end

                local headers_map = {}
                for line in header_part:gmatch("[^\r\n]+") do
                    local k, v = line:match("^([^:]+)%s*:%s*(.*)$")
                    if k and v then
                        headers_map[k:lower()] = v:gsub("%s+$", "")
                    end
                end

                local status = tonumber(header_part:match("^HTTP/%d+%.?%d*%s+(%d+)")) or 200
                return { status = status, body = body_part or "", headers = headers_map }
            end
        end
        pcall(os.remove, tmp_file)
    end

    error("No supported HTTP transport available. Provide options.http_handler or install LuaSec/curl.")
end

return http
    end

    ----------------------------------------------------------------------------
    -- Module: epicauth.client (E:\GitHub\epicauth-org\EpicAuth-Lua-SDK\src\epicauth\client.lua)
    ----------------------------------------------------------------------------
    _modules["epicauth.client"] = function(require, _LOADED)
local client = {}

local function load_internal(name)
    local ok, mod = pcall(require, "epicauth." .. name)
    if ok then return mod end
    ok, mod = pcall(require, "src.epicauth." .. name)
    if ok then return mod end
    return require(name)
end

local EpicAuthError = load_internal("errors")
local JSON = load_internal("json")
local crypto = load_internal("crypto")
local http = load_internal("http")
local hwid_mod = load_internal("hwid")

local EpicAuth = {}
EpicAuth.__index = EpicAuth

function EpicAuth.new(options)
    options = options or {}
    local name = options.name
    local ownerid = options.ownerid
    local version = options.version

    if not name or not ownerid or not version then
        error("Name, ownerid, and version are required")
    end

    local self = setmetatable({}, EpicAuth)
    self.name = tostring(name)
    self.ownerid = tostring(ownerid)
    self.version = tostring(version)
    self.hash_to_check = options.hash_to_check
    self.url = options.url or "https://epicauth.cc/api/1.3/"
    self.path = options.path
    self.exitOnError = (options.exitOnError ~= false)
    self.loggingEnabled = options.loggingEnabled or false
    self.custom_hwid = options.hwid or options.custom_hwid or options.hwid_handler
    self.http_handler = options.http_handler

    self.sessionid = nil
    self.initialized = false
    self.public_key = "95b38710f40927b16528a073b87d942e03bd4578d49963a19ebae177945f89ac"

    self.user_data = nil
    self.app_data = nil

    return self
end

function EpicAuth:checkinit()
    if not self.sessionid and not self.initialized then
        return self:fail("You need to run the EpicAuthApp.init(); function before any other EpicAuth functions")
    end
end

function EpicAuth:getHWID()
    return hwid_mod.get(self.custom_hwid)
end

function EpicAuth:getUsername()
    if os and type(os.getenv) == "function" then
        return os.getenv("USERNAME") or os.getenv("USER") or "unknown"
    end
    return "unknown"
end

function EpicAuth:fail(message, ms)
    message = tostring(message or "Unknown error")
    if self.exitOnError then
        if io and io.stderr and type(io.stderr.write) == "function" then
            io.stderr:write(string.format("[EpicAuth] %s\n", message))
        else
            print(string.format("[EpicAuth] %s", message))
        end
        if ms and ms > 0 and os and type(os.execute) == "function" then
            local sec = math.ceil(ms / 1000)
            local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
                or (os and type(os.getenv) == "function" and (os.getenv("OS") or ""):find("Windows") ~= nil)
            if is_windows then
                os.execute("timeout /t " .. sec .. " >nul 2>nul || ping -n " .. (sec + 1) .. " 127.0.0.1 >nul 2>nul")
            else
                os.execute("sleep " .. sec .. " 2>/dev/null")
            end
        end
        if os and type(os.exit) == "function" then
            os.exit(1)
        else
            error(EpicAuthError.new(message))
        end
    end
    error(EpicAuthError.new(message))
end

function EpicAuth:redactField(content, field)
    return content:gsub('"' .. field .. '"%s*:%s*"[^"]*"', '"' .. field .. '": "[REDACTED]"')
end

function EpicAuth:logEvent(message)
    if not self.loggingEnabled then return end
    print(message)

    local exe_path = (arg and arg[0]) or "epicauth_app"
    local exe_name = exe_path:match("[^/\\]+$") or "epicauth_app"
    local home = (os and type(os.getenv) == "function" and (os.getenv("USERPROFILE") or os.getenv("HOME"))) or "."
    local log_dir = home .. "/.epicauth/logs/" .. exe_name

    pcall(function()
        local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
            or (os and type(os.getenv) == "function" and (os.getenv("OS") or ""):find("Windows") ~= nil)
        if os and type(os.execute) == "function" then
            if is_windows then
                os.execute('mkdir "' .. log_dir:gsub("/", "\\") .. '" 2>nul')
            else
                os.execute('mkdir -p "' .. log_dir .. '" 2>/dev/null')
            end
        end

        local date_str = (os and type(os.date) == "function" and os.date("%b_%d_%Y")) or "logs"
        local log_file = log_dir .. "/" .. date_str .. "_logs.txt"

        local sanitized = tostring(message)
        local sensitive = { "sessionid", "ownerid", "app", "version", "fileid", "webhooks", "nonce" }
        for _, f in ipairs(sensitive) do
            sanitized = self:redactField(sanitized, f)
        end

        if io and type(io.open) == "function" then
            local f = io.open(log_file, "a")
            if f then
                local iso_time = (os and type(os.date) == "function" and os.date("!%Y-%m-%dT%H:%M:%SZ")) or ""
                f:write(string.format("[%s] [%s] %s\n", iso_time, exe_name, sanitized))
                f:close()
            end
        end
    end)
end

function EpicAuth:load_app_data(data)
    if type(data) ~= "table" then return nil end
    self.app_data = {
        numUsers = tonumber(data.numUsers) or 0,
        numKeys = tonumber(data.numKeys) or 0,
        app_ver = tostring(data.version or ""),
        customer_panel = tostring(data.customerPanelLink or ""),
        onlineUsers = tonumber(data.numOnlineUsers) or 0,
    }
    return self.app_data
end

function EpicAuth:load_user_data(data)
    if type(data) ~= "table" then
        return self:fail("Invalid user info structure")
    end
    local subs = data.subscriptions or {}
    local primary = subs[1]
    if not primary then
        return self:fail("User has no subscriptions.")
    end

    self.user_data = {
        username = tostring(data.username or ""),
        ip = tostring(data.ip or ""),
        hwid = tostring(data.hwid or "N/A"),
        expires = tonumber(primary.expiry) or 0,
        createdate = tonumber(data.createdate) or 0,
        lastlogin = tonumber(data.lastlogin) or 0,
        subscription = tostring(primary.subscription or ""),
        subscriptions = subs,
    }
    return self.user_data
end

function EpicAuth:displayQrCode(qrCodeUrl)
    if not qrCodeUrl or #qrCodeUrl == 0 then return end
    if not os or type(os.execute) ~= "function" then return end
    local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
        or (os and type(os.getenv) == "function" and (os.getenv("OS") or ""):find("Windows") ~= nil)
    if is_windows then
        os.execute(string.format('start "" "%s"', qrCodeUrl))
    else
        os.execute(string.format('xdg-open "%s" 2>/dev/null || open "%s" 2>/dev/null', qrCodeUrl, qrCodeUrl))
    end
end

function EpicAuth:request(body)
    local post_str = http.build_query(body)
    local ok_http, resp = pcall(http.post, self.url, post_str, self.http_handler)
    if not ok_http or not resp or resp.status ~= 200 then
        local status = resp and resp.status or "network error"
        return self:fail("HTTP " .. tostring(status))
    end

    local rawBody = resp.body or ""
    if rawBody == "EpicAuth_Invalid" then
        return rawBody
    end

    local data = JSON.decode(rawBody)
    if not data then
        return self:fail("Failed to parse response JSON: " .. rawBody:sub(1, 80))
    end

    local req_type = tostring(body.type)
    local excluded = { file = true, log = true, ["2faenable"] = true, ["2fadisable"] = true }
    if excluded[req_type] then
        return data
    end

    local signature = resp.headers["x-signature-ed25519"]
    local timestamp = resp.headers["x-signature-timestamp"]

    if not signature or not timestamp then
        return self:fail("Missing signature or timestamp in response headers")
    end

    local server_time = tonumber(timestamp)
    local current_time = os.time()
    if server_time and current_time then
        local time_diff = math.abs(server_time - current_time)
        if time_diff > 25 then
            return self:fail(string.format(
                "Time difference is too large: %d seconds, try syncing your date and time settings.",
                time_diff
            ))
        end
    end

    local message = timestamp .. rawBody
    local valid, err = crypto.verify_signature(signature, message, self.public_key)
    if valid == false then
        return self:fail("Signature checksum failed. Request was tampered with or session ended most likely.", 3000)
    end

    self:logEvent(JSON.encode(data) .. "\n")
    return data
end

function EpicAuth:init()
    if not self.sessionid and self.initialized then
        return self:fail("Application already initialized", 0)
    end

    local token = ""
    local thash = nil
    if self.path then
        local f = io.open(self.path, "r")
        if not f then
            return self:fail(string.format("Failed to read file at path %s", self.path), 0)
        end
        token = f:read("*a") or ""
        f:close()
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        thash = crypto.sha256(token)
    end

    local body = {
        type = "init",
        ownerid = self.ownerid,
        version = self.version,
        name = self.name,
        hash = self.hash_to_check,
        token = (self.path and token) or nil,
        thash = thash,
    }

    local response = self:request(body)
    if response == "EpicAuth_Invalid" then
        return self:fail("This application does not exist")
    end

    if response.message == "invalidver" then
        if response.download and #response.download > 0 then
            print("Your application is outdated.")
            if os and type(os.execute) == "function" then
                local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
                    or (os and type(os.getenv) == "function" and (os.getenv("OS") or ""):find("Windows") ~= nil)
                if is_windows then
                    os.execute(string.format('start "" "%s"', response.download))
                else
                    os.execute(string.format('xdg-open "%s" 2>/dev/null || open "%s" 2>/dev/null', response.download, response.download))
                end
            end
            return self:fail("use latest update")
        else
            return self:fail("Your application is outdated and no download link was provided, contact the owner for the latest app version.")
        end
    end

    if response.success == false then
        return self:fail(response.message)
    end

    if response.sessionid then
        self.sessionid = response.sessionid
        self.initialized = true
    end

    if response.appinfo then
        self:load_app_data(response.appinfo)
    end

    return true, response
end

function EpicAuth:login(options, password, code, hwid)
    self:checkinit()

    local username
    if type(options) == "table" then
        username = options.username
        password = options.password or options.pass
        code = options.code
        hwid = options.hwid
    else
        username = options
    end

    if not hwid then hwid = self:getHWID() end

    local body = {
        type = "login",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        username = username,
        pass = password,
        hwid = hwid,
        code = code,
    }

    local response = self:request(body)
    if response.success == true then
        self:logEvent(response.message)
        self:load_user_data(response.info)
        return true, response
    else
        self:logEvent(response.message)
        return self:fail(response.message)
    end
end

function EpicAuth:license(options, code, hwid)
    self:checkinit()

    local key
    if type(options) == "table" then
        key = options.license or options.key
        code = options.code
        hwid = options.hwid
    else
        key = options
    end

    if not hwid then hwid = self:getHWID() end

    local body = {
        type = "license",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        key = key,
        hwid = hwid,
        code = code,
    }

    local response = self:request(body)
    if response.success == true then
        self:logEvent(response.message)
        self:load_user_data(response.info)
        return true, response
    else
        self:logEvent(response.message)
        return self:fail(response.message)
    end
end

function EpicAuth:register(options, password, key, hwid)
    self:checkinit()

    local username
    if type(options) == "table" then
        username = options.username
        password = options.password or options.pass
        key = options.license or options.key
        hwid = options.hwid
    else
        username = options
    end

    if not hwid then hwid = self:getHWID() end

    local body = {
        type = "register",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        username = username,
        pass = password,
        key = key,
        hwid = hwid,
    }

    local response = self:request(body)
    if response.success == true then
        self:logEvent(response.message)
        self:load_user_data(response.info)
        return true, response
    else
        self:logEvent(response.message)
        return self:fail(response.message)
    end
end

function EpicAuth:upgrade(options, key)
    self:checkinit()

    local username
    if type(options) == "table" then
        username = options.username
        key = options.license or options.key
    else
        username = options
    end

    local body = {
        type = "upgrade",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        username = username,
        key = key,
    }

    local response = self:request(body)
    if response.success == true then
        self:logEvent(response.message)
        return self:fail("Restart the application to apply the changes.")
    else
        self:logEvent(response.message)
        return self:fail(response.message)
    end
end

function EpicAuth:var(options)
    self:checkinit()
    local name = type(options) == "table" and options.name or options

    local body = {
        type = "var",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        varid = name,
    }

    local response = self:request(body)
    if response.success == true then
        self:logEvent(response.message)
        return response.message
    else
        return self:fail(response.message or "var error")
    end
end

function EpicAuth:getvar(options)
    self:checkinit()
    local name = type(options) == "table" and options.name or options

    local body = {
        type = "getvar",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        var = name,
    }

    local response = self:request(body)
    if response.success == true then
        self:logEvent(response.message)
        return response.response
    else
        return self:fail(response.message or "getvar error")
    end
end

function EpicAuth:setvar(options, value)
    self:checkinit()
    local name
    if type(options) == "table" then
        name = options.name
        value = options.value
    else
        name = options
    end

    local body = {
        type = "setvar",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        varid = name,
        data = value,
    }

    local response = self:request(body)
    if response.success == true then
        return true
    else
        return self:fail(response.message or "setvar error")
    end
end

function EpicAuth:ban()
    self:checkinit()
    local body = {
        type = "ban",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
    }

    local response = self:request(body)
    if response.success == true then
        return true
    else
        return self:fail(response.message)
    end
end

function EpicAuth:file(options)
    self:checkinit()
    local id = type(options) == "table" and options.id or options

    local body = {
        type = "file",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        fileid = id,
    }

    local response = self:request(body)
    if response.success == true then
        return response.contents
    else
        return self:fail(response.message)
    end
end

function EpicAuth:webhook(options)
    self:checkinit()
    options = options or {}

    local body = {
        type = "webhook",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        webid = options.id,
        params = options.param,
        body = options.body,
        conttype = options.conttype,
    }

    local response = self:request(body)
    if response.success == true then
        return response.message or response.response
    else
        return self:fail(response.message)
    end
end

function EpicAuth:check()
    self:checkinit()
    local body = {
        type = "check",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
    }

    local response = self:request(body)
    if response.success == true then
        return true
    else
        return self:fail(response.message)
    end
end

function EpicAuth:checkblacklist()
    self:checkinit()
    local body = {
        type = "checkblacklist",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        hwid = self:getHWID(),
    }

    local response = self:request(body)
    if response.success == true then
        return true
    else
        return self:fail(response.message)
    end
end

function EpicAuth:log(options)
    self:checkinit()
    local message = type(options) == "table" and options.message or options

    local body = {
        type = "log",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        message = message,
        pcuser = self:getUsername(),
    }

    return self:request(body)
end

function EpicAuth:fetchOnline()
    self:checkinit()
    local body = {
        type = "fetchOnline",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
    }

    local response = self:request(body)
    if response.success == true then
        if response.users then
            return tonumber(response.users) or response.users
        end
        return nil
    else
        return false
    end
end

function EpicAuth:fetchStats()
    self:checkinit()
    local body = {
        type = "fetchStats",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
    }

    local response = self:request(body)
    if response.success == true then
        return self:load_app_data(response.appinfo)
    else
        return self:fail(response.message or "fetchStats failed")
    end
end

function EpicAuth:chatGet(options)
    self:checkinit()
    local channel = type(options) == "table" and options.channel or options

    local body = {
        type = "chatget",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        channel = channel,
    }

    local response = self:request(body)
    if response.success == true then
        return response.messages
    else
        return false
    end
end

function EpicAuth:chatSend(options, channel)
    self:checkinit()
    local message
    if type(options) == "table" then
        message = options.message
        channel = options.channel
    else
        message = options
    end

    local body = {
        type = "chatsend",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        channel = channel,
        message = message,
    }

    local response = self:request(body)
    if response.success == true then
        return true
    else
        return false
    end
end

function EpicAuth:changeUsername(options)
    self:checkinit()
    local username = type(options) == "table" and options.username or options

    local body = {
        type = "changeUsername",
        newUsername = username,
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
    }

    local response = self:request(body)
    if response.success == true then
        if self.user_data then
            self.user_data.username = username
        end
        print("Username changed successfully")
        return true
    else
        return false
    end
end

function EpicAuth:logout()
    self:checkinit()
    local body = {
        type = "logout",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
    }

    local response = self:request(body)
    self.sessionid = nil
    self.initialized = false
    self.user_data = nil

    if response.success == true then
        return self:fail("Logged out successfully")
    else
        return self:fail(response.message)
    end
end

function EpicAuth:enable2fa(options)
    self:checkinit()
    local code = type(options) == "table" and options.code or options

    local body = {
        type = "2faenable",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        code = code,
    }

    local response = self:request(body)
    if response.success == true then
        if not code and response["2fa"] then
            print("Your 2fa secret code is: " .. tostring(response["2fa"].secret_code))
            if response["2fa"].QRCode then
                self:displayQrCode(response["2fa"].QRCode)
            end
            print("Please enter the code you received in your authenticator app.")
            io.write("Enter the code: ")
            io.flush()
            local userCode = io.read()
            return self:enable2fa({ code = userCode })
        else
            print("2FA enabled successfully")
            return response
        end
    else
        self:logEvent(response.message)
        if type(os.exit) == "function" then
            os.exit(0)
        end
    end
end

function EpicAuth:disable2fa(options)
    self:checkinit()
    local code
    if type(options) == "table" then
        code = options.code
    else
        code = options
    end

    if not code then
        io.write("Enter the code: ")
        io.flush()
        code = io.read()
    end

    local body = {
        type = "2fadisable",
        name = self.name,
        ownerid = self.ownerid,
        sessionid = self.sessionid,
        code = code,
    }

    local response = self:request(body)
    self:logEvent(response.message)
    return response
end

client.EpicAuth = EpicAuth
return client
    end

    ----------------------------------------------------------------------------
    -- Module: epicauth.init (E:\GitHub\epicauth-org\EpicAuth-Lua-SDK\src\epicauth\init.lua)
    ----------------------------------------------------------------------------
    _modules["epicauth.init"] = function(require, _LOADED)
local function load_internal(name)
    local ok, mod = pcall(require, "epicauth." .. name)
    if ok then return mod end
    ok, mod = pcall(require, "src.epicauth." .. name)
    if ok then return mod end
    return require(name)
end

local client = load_internal("client")
local EpicAuthError = load_internal("errors")

local EpicAuth = client.EpicAuth
EpicAuth.EpicAuth = EpicAuth
EpicAuth.EpicAuthError = EpicAuthError

setmetatable(EpicAuth, {
    __call = function(_, options)
        return EpicAuth.new(options)
    end
})

return EpicAuth
    end

    -- Export the root EpicAuth SDK module
    return _custom_require("epicauth.init")
end)(...)
