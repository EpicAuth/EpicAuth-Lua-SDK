---
name: epicauth-lua
description: Comprehensive expert guide for AI agents to integrate, configure, and troubleshoot the EpicAuth Lua SDK for licensing, authentication, HWID locking, and software protection across Lua 5.1-5.4, LuaJIT, Roblox, and FiveM.
---

# EpicAuth Lua SDK - Agent Integration Skill

Use this skill whenever generating, refactoring, or debugging code that integrates the **EpicAuth** authentication and licensing system in Lua projects.

---

## 1. Core Rules for Agents

1. **Mandatory Lifecycle**:
   - Always call `app:init()` **once** at the start before any other EpicAuth method.
   - Never call `app:license()`, `app:login()`, `app:var()`, or other functions before `app:init()`.

2. **Error Handling Mode (`exitOnError`)**:
   - **CLI / Desktop tools**: Use `exitOnError = true` (default). Critical errors automatically print to `io.stderr` and exit with code 1.
   - **Servers & Game Environments (Roblox / FiveM)**: **Always** set `exitOnError = false`. Failing to do so will terminate the entire server or game process. Wrap calls in `pcall(function() ... end)`.

3. **User Profile Verification**:
   - Access `app.user_data` only after a successful `app:license()`, `app:login()`, or `app:register()` call.
   - `app.user_data.expires` is a Unix timestamp in seconds. Compare against `os.time()` to verify remaining validity.
   - Primary subscription name is found in `app.user_data.subscription`.

---

## 2. Standard Client Initialization

```lua
local EpicAuth = require("epicauth")

local app = EpicAuth.new({
    name = "ApplicationName",       -- Dashboard Application Name
    ownerid = "YOUR_OWNER_ID",     -- 10-character Account Owner ID
    version = "1.0",               -- Application Version
    exitOnError = false,           -- Recommended false for resilience
    loggingEnabled = false         -- Optional local log auditing
})

-- Step 1: Initialize
local ok, err = pcall(function()
    app:init()
end)

if not ok then
    error("Failed to connect to authentication server: " .. tostring(err))
end
```

---

## 3. Recommended Code Patterns

### Pattern A: License Key Verification (Standard)
```lua
local function verifyLicense(licenseKey)
    local ok, res = pcall(function()
        return app:license({ license = licenseKey })
    end)

    if not ok then
        return false, "Authentication failed: " .. tostring(res)
    end

    local user = app.user_data
    return true, {
        username = user.username,
        subscription = user.subscription,
        expires = user.expires,
        isExpired = (user.expires > 0 and user.expires < os.time())
    }
end
```

### Pattern B: Username & Password Login
```lua
local function login(username, password)
    local ok, res = pcall(function()
        return app:login({
            username = username,
            password = password
        })
    end)

    if not ok then
        return false, tostring(res)
    end

    return true, app.user_data
end
```

### Pattern C: Fetching Remote Server Variables
```lua
-- Fetch global variable (e.g. encrypted config or feature flags)
local ok, configValue = pcall(function()
    return app:var({ name = "SecretConfig" })
end)

if ok then
    print("Received remote config:", configValue)
end
```

### Pattern D: Secure File Download
```lua
-- Download protected binary/script by File ID from dashboard
local ok, fileBytes = pcall(function()
    return app:file({ id = "123456" })
end)

if ok then
    -- Execute or save file
    local fn = loadstring or load
    local scriptFunc = fn(fileBytes)
    if scriptFunc then scriptFunc() end
end
```

---

## 4. Environment-Specific Adaptations

### Roblox (`ServerScriptService`)
```lua
-- In Roblox, require the ModuleScript
local EpicAuth = require(game.ServerScriptService.EpicAuth)

local app = EpicAuth.new({
    name = "RobloxHub",
    ownerid = "1234567890",
    version = "1.0",
    exitOnError = false
})

app:init()
```

### FiveM Server Script (`server.lua`)
```lua
local EpicAuth = require("epicauth")

local app = EpicAuth.new({
    name = "FiveMMod",
    ownerid = "1234567890",
    version = "1.0",
    exitOnError = false
})

CreateThread(function()
    local ok, err = pcall(function() app:init() end)
    if not ok then
        print("^1[Auth] Connection failed: " .. tostring(err) .. "^0")
    end
end)
```

---

## 5. Common Agent Mistakes to Avoid

| Bad Practice | Correct Practice |
| :--- | :--- |
| Calling `app:license()` before `app:init()` | Always call `app:init()` once during startup |
| Setting `exitOnError = true` inside FiveM or Roblox | Set `exitOnError = false` so errors don't terminate server |
| Hardcoding HWID manually | Let `app:getHWID()` automatically calculate platform HWID |
| Assuming `expires` is a formatted date | `expires` is a Unix timestamp; format with `os.date("%Y-%m-%d", app.user_data.expires)` |
| Missing required options in constructor | `name`, `ownerid`, and `version` are mandatory; constructor throws if omitted |
