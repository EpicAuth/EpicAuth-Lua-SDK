# EpicAuth Lua SDK

Official Lua SDK for [EpicAuth](https://epicauth.cc) authentication, licensing, and software protection platform. Ported with 100% parity from the official [EpicAuth TypeScript SDK](https://github.com/EpicAuth/EpicAuth-TS-SDK).

Compatible with **Lua 5.1, 5.2, 5.3, 5.4**, and **LuaJIT**, as well as game environments (Roblox, FiveM, GameGuardian, SLua).

---

## Distribution & Installation

EpicAuth Lua SDK offers three distribution targets tailored to different developer workflows and execution environments:

### 1. Package Manager (LuaRocks)
For standard Lua development (CLI tools, server daemons, desktop applications) with LuaRocks:

```bash
luarocks install epicauth
```

In your code:
```lua
local EpicAuth = require("epicauth")
```

---

### 2. Single-File Standalone Bundle (`epicauth.bundle.lua`)
For embedded runtimes, game engines (**Roblox**, **FiveM**, **GameGuardian**), plugin sandboxes, or environments without package managers or filesystem access.

Download `epicauth.bundle.lua` from [GitHub Releases](https://github.com/EpicAuth/EpicAuth-Lua-SDK/releases) (or build it from source with `lua scripts/bundle.lua`), and load it using any standard Lua loader:

```lua
-- Option A: Direct file execution (recommended for sandboxes/scripts)
local EpicAuth = dofile("epicauth.bundle.lua")

-- Option B: Evaluated chunk execution
local EpicAuth = loadfile("epicauth.bundle.lua")()

-- Option C: Standard require (when placed inside package.path)
local EpicAuth = require("epicauth.bundle")
```

The bundle is completely self-contained with a fallback internal module registry and lazy loader. Internal submodules (`epicauth.client`, `epicauth.crypto`, etc.) resolve properly even in strict sandboxes where the global `package` table is restricted.

---

### 3. Multi-File Source Integration (Vendoring)
For source-level integration without package managers, download `epicauth-lua-sdk-source.zip` from Releases or copy `epicauth.lua` and the `src/` directory directly into your project:

```text
your-project/
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

In your code:
```lua
-- Ensure package.path includes project root if needed:
package.path = "./?.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local EpicAuth = require("epicauth")
```

---

### Building the Single-File Bundle from Source

To package all modules in `src/epicauth/` into `dist/epicauth.bundle.lua`:

```bash
lua scripts/bundle.lua
```

Options:
- `--output <path>`: Specify custom destination path (default: `dist/epicauth.bundle.lua`).
- `--no-verify`: Skip post-build syntax and export validation.

---

## Quick Start

### 1. Define Instance
Retrieve your credentials from [EpicAuth Dashboard](https://epicauth.cc/app/):

```lua
local EpicAuth = require("epicauth")

local app = EpicAuth.new({
    name = "MyAppName",       -- Application Name
    ownerid = "YOUR_OWNER_ID", -- Account Owner ID (10 characters)
    version = "1.0",           -- Application Version
    exitOnError = true,        -- Exit process on critical error (default: true)
    loggingEnabled = false     -- Write sanitized logs to ~/.epicauth/logs (default: false)
})
```

### 2. Initialize
Must be called once at application startup before invoking any other EpicAuth functions:

```lua
app:init()
```

### 3. Display Application Statistics

```lua
app:fetchStats()

print(string.format([[
App Data:
  Number of users: %s
  Online users: %s
  Number of keys: %s
  Application Version: %s
  Customer panel link: %s
]], app.app_data.numUsers, app.app_data.onlineUsers, app.app_data.numKeys, app.app_data.app_ver, app.app_data.customer_panel))
```

---

## Authentication Examples

### License Key Authentication
```lua
app:license({ license = "YOUR_LICENSE_KEY" })

print("Username:", app.user_data.username)
print("Subscription:", app.user_data.subscription)
print("Expires:", app.user_data.expires)
```

### Username & Password Login
```lua
app:login({
    username = "username",
    password = "password"
})

print("Welcome back:", app.user_data.username)
```

### Register New User
```lua
app:register({
    username = "username",
    password = "password",
    license = "YOUR_LICENSE_KEY"
})
```

### Upgrade User Expiry
```lua
app:upgrade({
    username = "username",
    license = "NEW_UNUSED_KEY"
})
```

---

## API Reference

| Method | Parameters | Return | Description |
| :--- | :--- | :--- | :--- |
| `init()` | — | `boolean, table` | Initializes session and verifies integrity |
| `license(options)` | `{ license, code?, hwid? }` | `boolean, table` | Authenticates using a license key |
| `login(options)` | `{ username, password, code?, hwid? }` | `boolean, table` | Logs in using username and password |
| `register(options)` | `{ username, password, license, hwid? }` | `boolean, table` | Registers a new user account |
| `upgrade(options)` | `{ username, license }` | `boolean` | Upgrades an existing account with an unused license |
| `var(options)` | `{ name }` | `string` | Retrieves a server-side global variable |
| `getvar(options)` | `{ name }` | `string` | Retrieves a user-specific variable |
| `setvar(options)` | `{ name, value }` | `boolean` | Updates a user-specific variable |
| `ban()` | — | `boolean` | Bans the currently authenticated user |
| `file(options)` | `{ id }` | `string` | Downloads server-side file contents by ID |
| `webhook(options)` | `{ id, param, body?, conttype? }` | `string` | Triggers a server-configured webhook |
| `check()` | — | `boolean` | Verifies current session validity |
| `checkblacklist()` | — | `boolean` | Checks if current machine HWID is blacklisted |
| `log(options)` | `{ message }` | `table` | Sends application log message to EpicAuth |
| `fetchOnline()` | — | `number` | Returns number of online users |
| `fetchStats()` | — | `table` | Fetches application metadata into `app.app_data` |
| `chatGet(options)` | `{ channel }` | `table` | Retrieves messages from a chat channel |
| `chatSend(options)` | `{ message, channel }` | `boolean` | Sends a message to a chat channel |
| `changeUsername(options)` | `{ username }` | `boolean` | Updates current user's username |
| `logout()` | — | `boolean` | Terminates active session and clears user data |
| `enable2fa(options)` | `{ code? }` | `table` | Enables 2-factor authentication |
| `disable2fa(options)` | `{ code? }` | `table` | Disables 2-factor authentication |
| `getHWID()` | — | `string` | Returns cross-platform Hardware ID |

---

## Data Structures

### `app.user_data`
Populated automatically upon successful login, license check, or registration:
```lua
{
    username = "example_user",
    ip = "1.2.3.4",
    hwid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    expires = 1774000000,
    createdate = 1700000000,
    lastlogin = 1705000000,
    subscription = "Default",
    subscriptions = { ... }
}
```

### `app.app_data`
Populated when `init()` or `fetchStats()` is called:
```lua
{
    numUsers = 150,
    numKeys = 200,
    onlineUsers = 12,
    app_ver = "1.0",
    customer_panel = "https://..."
}
```

---

## Options

`EpicAuth.new(options)` supports the following configuration table:

- `name` *(string, required)*: Application name.
- `ownerid` *(string, required)*: 10-character Account Owner ID.
- `version` *(string, required)*: Application version.
- `hash_to_check` *(string, optional)*: Hash value checked against dashboard release integrity.
- `url` *(string, optional)*: API endpoint (default: `https://epicauth.cc/api/1.3/`).
- `path` *(string, optional)*: File path to read session token from.
- `exitOnError` *(boolean, optional, default: true)*: If `true`, prints error and exits process on critical failure. If `false`, raises an `EpicAuthError`.
- `loggingEnabled` *(boolean, optional, default: false)*: Enables local audit logs in `~/.epicauth/logs/`.
- `http_handler` *(function, optional)*: Custom HTTP transport handler for sandboxed or game runtimes (e.g., `fn(url, headers, body)` or table options). Supports returning status/body/headers table or `(body, status, headers)`.
- `hwid` *(string | function, optional)*: Explicit hardware identifier string or custom HWID provider callback function `fn() -> string`.
- `hwid_handler` *(function, optional)*: Alias for providing a custom HWID generation callback.

---

## Error Handling

When `exitOnError = false`, errors throw `EpicAuthError`:

```lua
local EpicAuth = require("epicauth")
local EpicAuthError = EpicAuth.EpicAuthError

local app = EpicAuth.new({
    name = "MyApp",
    ownerid = "YOUR_OWNER_ID",
    version = "1.0",
    exitOnError = false
})

local ok, err = pcall(function()
    app:init()
    app:license({ license = "INVALID-KEY" })
end)

if not ok then
    print("Caught error:", err.message)
end
```

---

## Documentation

Comprehensive guides are available in the [`docs/`](docs/) directory:

- [Getting Started Guide](docs/getting-started.md)
- [Full API Reference](docs/api-reference.md)
- [Game Engine Guides (Roblox, FiveM, GameGuardian)](docs/game-environments.md)
- [Security & Integrity Model](docs/security.md)

---

## AI Agents & Skills

For developers using AI coding assistants (Antigravity, Cursor, Claude Code, Windsurf), an integration skill is included at [`skills/epicauth/SKILL.md`](skills/epicauth/SKILL.md) and [`.agent/skills/epicauth/SKILL.md`](.agent/skills/epicauth/SKILL.md).

It instructs AI agents on proper initialization lifecycles, sandbox error modes, subscription checks, and copy-paste-ready patterns.

---

## Publishing to LuaRocks (CI/CD)

A GitHub Actions workflow is provided at `.github/workflows/publish.yml`.

1. Go to repository **Settings > Secrets and variables > Actions**.
2. Add a repository secret named `LUAROCKS_API_KEY` with your LuaRocks API key.
3. Push a version tag:
   ```bash
   git tag v1.0.3
   git push origin v1.0.3
   ```
   The workflow will automatically validate the rockspec and upload the package to [LuaRocks.org](https://luarocks.org).

---

## License

Elastic License 2.0. See [LICENSE](LICENSE) for details.
