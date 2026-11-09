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
