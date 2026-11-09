# Getting Started with EpicAuth Lua SDK

This guide walks you through setting up and using the EpicAuth Lua SDK in your application.

## 1. Installation

### LuaRocks
Install the package globally or into your local project tree:

```bash
luarocks install epicauth
```

### Direct Download / Vendoring
If you prefer not to use a package manager (e.g. in game scripts or standalone binaries), copy `epicauth.lua` and the `src/` directory into your project:

```lua
local EpicAuth = require("epicauth")
```

---

## 2. Configuration Options

Pass your application credentials from the [EpicAuth Dashboard](https://epicauth.cc/app/) to `EpicAuth.new()`:

```lua
local EpicAuth = require("epicauth")

local app = EpicAuth.new({
    name = "MyAppName",       -- Application Name (required)
    ownerid = "YOUR_OWNER_ID", -- Account Owner ID (10 chars, required)
    version = "1.0",           -- Application Version (required)
    hash_to_check = "",        -- Optional: Release hash check
    url = "https://epicauth.cc/api/1.3/", -- Optional: API endpoint
    path = nil,                -- Optional: Path to read session token from file
    exitOnError = true,        -- Optional: Exit process on failure (default: true)
    loggingEnabled = false,    -- Optional: Audit logs in ~/.epicauth/logs (default: false)
    hwid = nil,                -- Optional: Manual hardware ID override
    http_handler = nil         -- Optional: Custom HTTP transport function
})
```

---

## 3. Initialization Lifecycle

Call `init()` **once** at the start of your program before calling any other EpicAuth method:

```lua
app:init()
```

If `exitOnError = true` (default), any initialization failure (e.g., outdated app version, invalid credentials) will print an error message and terminate the process with exit code 1.

If `exitOnError = false`, failures raise an `EpicAuthError` that can be handled using `pcall`:

```lua
local ok, err = pcall(function()
    app:init()
end)

if not ok then
    print("Initialization failed:", err.message)
    return
end
```

---

## 4. Basic Authentication Flow

### License Key Only
Most licensing workflows only require validating a license key:

```lua
app:license({ license = "YOUR-LICENSE-KEY" })

print("Logged in as:", app.user_data.username)
print("Subscription:", app.user_data.subscription)
print("Expiry Unix:", app.user_data.expires)
```

### Username and Password
```lua
app:login({
    username = "john_doe",
    password = "secret_password"
})

print("Welcome back:", app.user_data.username)
```
