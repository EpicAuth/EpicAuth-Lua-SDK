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
    self.custom_hwid = options.hwid
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
    return os.getenv("USERNAME") or os.getenv("USER") or "unknown"
end

function EpicAuth:fail(message, ms)
    message = tostring(message or "Unknown error")
    if self.exitOnError then
        io.stderr:write(string.format("[EpicAuth] %s\n", message))
        if ms and ms > 0 and type(os.execute) == "function" then
            local sec = math.ceil(ms / 1000)
            if package.config:sub(1, 1) == "\\" then
                os.execute("timeout /t " .. sec .. " >nul 2>nul || ping -n " .. (sec + 1) .. " 127.0.0.1 >nul 2>nul")
            else
                os.execute("sleep " .. sec .. " 2>/dev/null")
            end
        end
        if type(os.exit) == "function" then
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
    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or "."
    local log_dir = home .. "/.epicauth/logs/" .. exe_name

    pcall(function()
        if package.config:sub(1, 1) == "\\" then
            os.execute('mkdir "' .. log_dir:gsub("/", "\\") .. '" 2>nul')
        else
            os.execute('mkdir -p "' .. log_dir .. '" 2>/dev/null')
        end

        local date_str = os.date("%b_%d_%Y")
        local log_file = log_dir .. "/" .. date_str .. "_logs.txt"

        local sanitized = tostring(message)
        local sensitive = { "sessionid", "ownerid", "app", "version", "fileid", "webhooks", "nonce" }
        for _, f in ipairs(sensitive) do
            sanitized = self:redactField(sanitized, f)
        end

        local f = io.open(log_file, "a")
        if f then
            local iso_time = os.date("!%Y-%m-%dT%H:%M:%SZ")
            f:write(string.format("[%s] [%s] %s\n", iso_time, exe_name, sanitized))
            f:close()
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
    local is_windows = (package.config:sub(1, 1) == "\\")
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
            local is_windows = (package.config:sub(1, 1) == "\\")
            if is_windows then
                os.execute(string.format('start "" "%s"', response.download))
            else
                os.execute(string.format('xdg-open "%s" 2>/dev/null || open "%s" 2>/dev/null', response.download, response.download))
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
