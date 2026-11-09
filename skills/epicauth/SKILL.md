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

2. **Distribution Target Selection**:
   - **Embedded Runtimes / Game Engines / Sandboxes**: Use the **single-file bundle** (`epicauth.bundle.lua`). Load via `local EpicAuth = dofile("epicauth.bundle.lua")`, `loadfile(...)()`, or paste directly into a Roblox `ModuleScript`. Do NOT attempt to install or require LuaRocks modules in sandboxes.
   - **Standard CLI / Desktop Tools with LuaRocks**: Use `local EpicAuth = require("epicauth")`.
   - **Vendored Multi-File Repositories**: Ensure `package.path` includes `./?.lua;./src/?.lua;./src/?/init.lua;` before calling `require("epicauth")`.

3. **Error Handling Mode (`exitOnError`)**:
   - **CLI / Desktop tools**: Use `exitOnError = true` (default). Critical errors automatically print to `io.stderr` and exit with code 1.
   - **Servers & Game Environments (Roblox / FiveM / GameGuardian)**: **Always** set `exitOnError = false`. Failing to do so will terminate the entire server or game process. Wrap calls in `pcall(function() ... end)`.

4. **User Profile Verification**:
   - Access `app.user_data` only after a successful `app:license()`, `app:login()`, or `app:register()` call.
   - `app.user_data.expires` is a Unix timestamp in seconds. Compare against `os.time()` to verify remaining validity.
   - Primary subscription name is found in `app.user_data.subscription`.

---

## 2. Loader Selection by Runtime Capability

```lua
-- Target A: Standalone Bundle (Recommended for Sandboxes, Game Engines, Single-File Scripts)
local EpicAuth = dofile("epicauth.bundle.lua")

-- Target B: Standard Package Manager (LuaRocks)
local EpicAuth = require("epicauth")

-- Target C: Roblox ModuleScript
local EpicAuth = require(game.ServerScriptService.EpicAuth)
```

---

## 3. Standard Client Initialization

```lua
local app = EpicAuth.new({
    name = "ApplicationName",       -- Dashboard Application Name (required)
    ownerid = "YOUR_OWNER_ID",     -- 10-character Account Owner ID (required)
    version = "1.0",               -- Application Version (required)
    exitOnError = false,           -- Recommended false for resilience
    loggingEnabled = false,        -- Optional local log auditing
    hwid = nil,                    -- Optional string or callback fn() -> string
    http_handler = nil             -- Optional custom HTTP adapter fn(url, headers, body)
})

-- Step 1: Initialize (Mandatory)
local ok, err = pcall(function()
    app:init()
end)

if not ok then
    error("Failed to connect to authentication server: " .. tostring(err))
end
```

---

## 4. Custom Adapters (Sandbox Overrides)

When working in environments without OS shell (`io.popen`) or sockets (e.g. custom game engines, locked Lua sandboxes), inject custom transport and HWID adapters:

```lua
local app = EpicAuth.new({
    name = "CustomRuntimeApp",
    ownerid = "YOUR_OWNER_ID",
    version = "1.0",
    exitOnError = false,

    -- Custom HWID provider (string or function)
    hwid = function()
        return GetCustomSystemGuid() or "FALLBACK-HWID"
    end,

    -- Custom HTTP transport adapter
    http_handler = function(url, headers, post_data)
        -- Adapt to native environment request API
        local response = NativeHttp.post({
            url = url,
            headers = headers,
            body = post_data
        })

        -- Return table with status, body, and headers
        return {
            status = response.code or 200,
            body = response.body or "",
            headers = response.headers or {}
        }
    end
})
```

---

## 5. Recommended Code Patterns

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
local ok, configValue = pcall(function()
    return app:var({ name = "SecretConfig" })
end)

if ok then
    print("Received remote config:", configValue)
end
```

### Pattern D: Secure File Download
```lua
local ok, fileBytes = pcall(function()
    return app:file({ id = "123456" })
end)

if ok then
    local fn = loadstring or load
    local scriptFunc = fn(fileBytes)
    if scriptFunc then scriptFunc() end
end
```

---

## 6. Environment-Specific Adaptations

### Roblox (`ServerScriptService`)
```lua
-- Paste epicauth.bundle.lua into ModuleScript named EpicAuth
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
-- Place epicauth.bundle.lua in resource root
local EpicAuth = dofile(GetResourcePath(GetCurrentResourceName()) .. "/epicauth.bundle.lua")

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

## 7. Common Agent Mistakes to Avoid

| Bad Practice | Correct Practice |
| :--- | :--- |
| Attempting to install or use `luarocks` in sandboxes | Use `epicauth.bundle.lua` via `dofile()` or ModuleScript |
| Calling `app:license()` before `app:init()` | Always call `app:init()` once during startup |
| Setting `exitOnError = true` inside FiveM or Roblox | Set `exitOnError = false` so errors don't terminate server |
| Hardcoding HWID manually when not needed | Let `app:getHWID()` automatically calculate platform HWID |
| Assuming `expires` is a formatted date | `expires` is a Unix timestamp; format with `os.date("%Y-%m-%d", app.user_data.expires)` |
| Missing required options in constructor | `name`, `ownerid`, and `version` are mandatory; constructor throws if omitted |
