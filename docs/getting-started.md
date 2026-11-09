# Getting Started with EpicAuth Lua SDK

This guide walks you through setting up and using the EpicAuth Lua SDK in your application.

## 1. Distribution & Installation Targets

EpicAuth Lua SDK supports three distinct integration approaches depending on your project type:

### Target A: LuaRocks Package Manager
Recommended for standard Lua command-line tools, daemon services, and desktop scripts:

```bash
luarocks install epicauth
```

In your scripts:
```lua
local EpicAuth = require("epicauth")
```

---

### Target B: Single-File Standalone Bundle (`epicauth.bundle.lua`)
Recommended for embedded game engines (**Roblox**, **FiveM**, **GameGuardian**), sandboxed plugins, or zero-dependency distributions where installing packages or bundling multiple directories is prohibited or impractical.

1. Download `epicauth.bundle.lua` from GitHub Releases (or generate it using `lua scripts/bundle.lua`).
2. Load it directly into your script:

```lua
-- Method 1: dofile (recommended for single-file scripts & local runtimes)
local EpicAuth = dofile("epicauth.bundle.lua")

-- Method 2: loadfile (evaluated chunk)
local EpicAuth = loadfile("epicauth.bundle.lua")()

-- Method 3: require (when placed inside package.path)
local EpicAuth = require("epicauth.bundle")
```

*Note: The bundle incorporates an internal fallback module registry so submodules (`epicauth.client`, `epicauth.crypto`, etc.) resolve properly even in locked-down sandboxes where `package.preload` or `package.loaded` are disabled.*

---

### Target C: Multi-File Source Integration (Vendoring)
If you prefer direct source integration without LuaRocks, copy `epicauth.lua` and the `src/` directory into your project structure:

```text
my_project/
├── epicauth.lua
├── src/
│   └── epicauth/
│       ├── init.lua
│       ├── client.lua
│       ├── crypto.lua
│       ├── errors.lua
│       ├── http.lua
│       ├── hwid.lua
│       └── json.lua
└── main.lua
```

In your scripts:
```lua
package.path = "./?.lua;./src/?.lua;./src/?/init.lua;" .. package.path
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
