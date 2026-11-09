# EpicAuth Lua SDK - API Reference

Comprehensive reference for all methods and properties available in `EpicAuth`.

---

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `name` | `string` | Application name. |
| `ownerid` | `string` | 10-character Account Owner ID. |
| `version` | `string` | Application version. |
| `sessionid` | `string \| nil` | Active session ID returned by `init()`. |
| `initialized` | `boolean` | `true` once `init()` succeeds. |
| `user_data` | `table \| nil` | Authenticated user profile data. |
| `app_data` | `table \| nil` | Application statistics from `init()` or `fetchStats()`. |

---

## Authentication Methods

### `app:init()`
Initializes session with the server and validates application state.
- **Parameters**: None.
- **Returns**: `boolean, table` on success.
- **Throws**: `EpicAuthError` if `exitOnError = false` and initialization fails.

### `app:license(options)`
Authenticates using a license key.
- **Parameters**:
  - `options.license` (`string`): License key.
  - `options.code` (`string`, optional): 2FA verification code.
  - `options.hwid` (`string`, optional): Custom hardware identifier.
- **Returns**: `boolean, table`.

### `app:login(options)`
Logs in with existing username and password credentials.
- **Parameters**:
  - `options.username` (`string`): Username.
  - `options.password` (`string`): Password.
  - `options.code` (`string`, optional): 2FA code.
  - `options.hwid` (`string`, optional): Custom hardware identifier.
- **Returns**: `boolean, table`.

### `app:register(options)`
Registers a new user account with a license key.
- **Parameters**:
  - `options.username` (`string`): Desired username.
  - `options.password` (`string`): Desired password.
  - `options.license` (`string`): Unused license key.
  - `options.hwid` (`string`, optional): Custom hardware identifier.
- **Returns**: `boolean, table`.

### `app:upgrade(options)`
Applies an unused license key to extend the expiry of an existing user.
- **Parameters**:
  - `options.username` (`string`): Existing username.
  - `options.license` (`string`): Unused license key.
- **Returns**: `boolean`.

### `app:logout()`
Terminates the active session and clears `user_data`.
- **Parameters**: None.
- **Returns**: `boolean`.

---

## Variables & Files

### `app:var(options)`
Fetches a global variable configured in the EpicAuth dashboard.
- **Parameters**: `options.name` (`string`) or string identifier.
- **Returns**: `string` (variable value).

### `app:getvar(options)`
Fetches a custom variable assigned specifically to the authenticated user.
- **Parameters**: `options.name` (`string`) or string identifier.
- **Returns**: `string` (variable value).

### `app:setvar(options)`
Sets or updates a custom variable for the authenticated user.
- **Parameters**:
  - `options.name` (`string`): Variable name.
  - `options.value` (`string`): Variable value.
- **Returns**: `boolean`.

### `app:file(options)`
Downloads file contents stored on EpicAuth by its File ID.
- **Parameters**: `options.id` (`string`) or string file ID.
- **Returns**: `string` (raw file contents).

### `app:webhook(options)`
Dispatches an event to a pre-configured webhook endpoint.
- **Parameters**:
  - `options.id` (`string`): Webhook ID.
  - `options.param` (`string`): Query parameters or URI segment.
  - `options.body` (`string`, optional): Request body payload.
  - `options.conttype` (`string`, optional): Content-Type header.
- **Returns**: `string` (server response).

---

## Session & Machine Verification

### `app:check()`
Verifies whether the current session is still valid on the server.
- **Parameters**: None.
- **Returns**: `boolean`.

### `app:checkblacklist()`
Checks whether the current device's HWID is blacklisted.
- **Parameters**: None.
- **Returns**: `boolean` (`true` if clean, fails if blacklisted).

### `app:ban()`
Bans the currently authenticated user.
- **Parameters**: None.
- **Returns**: `boolean`.

### `app:getHWID()`
Generates the platform-appropriate hardware identifier.
- **Parameters**: None.
- **Returns**: `string` (32-character or GUID identifier).

---

## Statistics & Community

### `app:fetchStats()`
Retrieves application statistics and updates `app.app_data`.
- **Returns**: `table` containing `numUsers`, `numKeys`, `onlineUsers`, `app_ver`, `customer_panel`.

### `app:fetchOnline()`
Retrieves current count of online users.
- **Returns**: `number` or `nil`.

### `app:log(options)`
Sends an audit log entry to the EpicAuth dashboard or linked Discord webhook.
- **Parameters**: `options.message` (`string`) or string message.
- **Returns**: `table`.

### `app:chatGet(options)`
Retrieves recent messages from a chat channel.
- **Parameters**: `options.channel` (`string`).
- **Returns**: `table` of messages `{ { author = "...", message = "...", timestamp = 123456 }, ... }`.

### `app:chatSend(options)`
Sends a message to a chat channel.
- **Parameters**:
  - `options.channel` (`string`): Channel name.
  - `options.message` (`string`): Message body.
- **Returns**: `boolean`.

### `app:changeUsername(options)`
Updates the username of the authenticated user.
- **Parameters**: `options.username` (`string`).
- **Returns**: `boolean`.

---

## Two-Factor Authentication (2FA)

### `app:enable2fa(options)`
Enables two-factor authentication. If called without a code, displays QR code and secret key, then prompts for the authenticator code.
- **Parameters**: `options.code` (`string`, optional).
- **Returns**: `table`.

### `app:disable2fa(options)`
Disables two-factor authentication.
- **Parameters**: `options.code` (`string`, optional). Prompts if omitted.
- **Returns**: `table`.
