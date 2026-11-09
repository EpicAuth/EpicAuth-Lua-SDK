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
    if custom_override and #custom_override > 0 then
        return custom_override
    end

    local is_windows = (package.config:sub(1, 1) == "\\")

    if is_windows and type(io.popen) == "function" then
        local ok, p = pcall(io.popen, 'reg query "HKLM\\SOFTWARE\\Microsoft\\Cryptography" /v MachineGuid 2>nul')
        if ok and p then
            local out = p:read("*a")
            p:close()
            local guid = out and out:match("MachineGuid%s+REG_SZ%s+([%w%-]+)")
            if guid and #guid > 5 then
                return guid
            end
        end

        local username = os.getenv("USERNAME") or ""
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

    if not is_windows and type(io.open) == "function" then
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

    local getenv = os.getenv or function() return nil end
    local fallback = table.concat({
        getenv("COMPUTERNAME") or getenv("HOSTNAME") or "DEVICE",
        getenv("USERNAME") or getenv("USER") or "USER",
        getenv("PROCESSOR_ARCHITECTURE") or getenv("HOSTTYPE") or "ARCH",
        getenv("PROCESSOR_IDENTIFIER") or getenv("OS") or "GENERIC",
        tostring(os.time())
    }, "|")

    return crypto.sha256(fallback):sub(1, 32)
end

return hwid
