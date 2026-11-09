# Game Engine & Environment Guides

EpicAuth Lua SDK automatically detects and adapts to game engine sandboxes without requiring external C libraries. You can use the single-file bundle (`epicauth.bundle.lua`) or the multi-file source.

---

## 1. Roblox Integration

Roblox requires `HttpService` enabled in Game Settings (`Home > Game Settings > Security > Allow HTTP Requests`).

### Installation via Single-File Bundle:
1. Create a **`ModuleScript`** in `ServerScriptService` (or `ReplicatedStorage`) and name it `EpicAuth`.
2. Paste the entire content of `epicauth.bundle.lua` into this `ModuleScript`.

### Server Script Example (`ServerScriptService`)
```lua
local HttpService = game:GetService("HttpService")
local EpicAuth = require(game.ServerScriptService.EpicAuth)

local app = EpicAuth.new({
    name = "RobloxGameHub",
    ownerid = "YOUR_OWNER_ID",
    version = "1.0",
    exitOnError = false -- Must be false in Roblox so server does not crash
})

local ok, initErr = pcall(function()
    app:init()
end)

if not ok then
    warn("[EpicAuth] Initialization failed: " .. tostring(initErr))
    return
end

-- Validate player key upon joining
game.Players.PlayerAdded:Connect(function(player)
    -- In a real scenario, receive license key from client via RemoteFunction
    local testKey = "USER-ENTERED-KEY"

    local success, res = pcall(function()
        return app:license({ license = testKey })
    end)

    if success then
        print(string.format("[EpicAuth] Player %s authenticated (%s)", player.Name, app.user_data.subscription))
    else
        player:Kick("Invalid or expired license key.")
    end
end)
```

---

## 2. FiveM Integration

FiveM servers run server-side Lua scripts. The SDK works out of the box using `curl` or a custom HTTP bridge using `PerformHttpRequest`.

### Installation via Single-File Bundle:
Place `epicauth.bundle.lua` inside your FiveM resource folder (e.g., `resources/[my-resource]/`) and load it via `dofile`:

```lua
local EpicAuth = dofile(GetResourcePath(GetCurrentResourceName()) .. "/epicauth.bundle.lua")
```

### Server Script Example (`server.lua`)
```lua
local EpicAuth = dofile(GetResourcePath(GetCurrentResourceName()) .. "/epicauth.bundle.lua")

local app = EpicAuth.new({
    name = "FiveMResource",
    ownerid = "YOUR_OWNER_ID",
    version = "1.0",
    exitOnError = false,
    -- Optional custom HWID using server license or IP
    hwid = function()
        return GetConvar("sv_licenseKeyToken", "fivem_server_default")
    end
})

CreateThread(function()
    local ok, err = pcall(function()
        app:init()
    end)

    if not ok then
        print("^1[EpicAuth] Failed to initialize: " .. tostring(err) .. "^0")
        return
    end

    print("^2[EpicAuth] Successfully connected. Session ID: " .. tostring(app.sessionid) .. "^0")
end)

-- Command to verify key
RegisterCommand("verifykey", function(source, args)
    local key = args[1]
    if not key then
        print("Usage: /verifykey <license>")
        return
    end

    local ok, res = pcall(function()
        return app:license({ license = key })
    end)

    if ok then
        print(string.format("^2[EpicAuth] Verified! Expiry: %s^0", os.date("%Y-%m-%d", app.user_data.expires)))
    else
        print("^1[EpicAuth] Verification failed: " .. tostring(res) .. "^0")
    end
end, false)
```

---

## 3. GameGuardian (Android)

GameGuardian scripts run in a restricted Lua sandbox. The SDK automatically detects `gg.makeRequest` and routes all network calls through it without shell access or sockets.

Using `epicauth.bundle.lua`:
```lua
local EpicAuth = dofile(gg.EXT_STORAGE .. "/epicauth.bundle.lua")

local app = EpicAuth.new({
    name = "GameModMenu",
    ownerid = "YOUR_OWNER_ID",
    version = "1.0",
    exitOnError = false
})

app:init()

local prompt = gg.prompt({"Enter License Key:"}, nil, {"text"})
if not prompt or not prompt[1] or #prompt[1] == 0 then
    gg.alert("No key provided.")
    os.exit()
end

local ok, res = pcall(function()
    return app:license({ license = prompt[1] })
end)

if ok then
    gg.toast("License verified! Welcome " .. app.user_data.username)
else
    gg.alert("Verification failed: " .. tostring(res))
    os.exit()
end
```
end

local ok, err = pcall(function()
    return app:license({ license = prompt[1] })
end)

if ok then
    gg.toast("License verified! Welcome " .. app.user_data.username)
    -- Launch script features
else
    gg.alert("Invalid Key: " .. tostring(err))
    os.exit()
end
```

---

## 4. Custom HTTP Handler

For proprietary engines or custom network stacks, supply `options.http_handler`:

```lua
local app = EpicAuth.new({
    name = "MyApp",
    ownerid = "YOUR_OWNER_ID",
    version = "1.0",
    http_handler = function(url, headers, body_str)
        -- Custom network call
        -- Must return a table with { status = <number>, body = <string>, headers = <table> }
        local response_body, status_code, response_headers = MyNetworkClient.post(url, headers, body_str)
        return {
            status = status_code or 200,
            body = response_body or "",
            headers = response_headers or {}
        }
    end
})
```
