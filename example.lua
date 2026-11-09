local EpicAuth = require("epicauth")

local app = EpicAuth.new({
    name = "MyAppName",
    ownerid = "YOUR_OWNER_ID",
    version = "1.0",
    exitOnError = true,
    loggingEnabled = false
})

app:init()

local stats = app:fetchStats()
if stats then
    print(string.format([[
App Data:
  Number of users: %s
  Online users: %s
  Number of keys: %s
  Application Version: %s
  Customer panel link: %s
]], stats.numUsers, stats.onlineUsers, stats.numKeys, stats.app_ver, stats.customer_panel))
end

-- Example 1: Authenticate with License Key
-- app:license({ license = "YOUR_LICENSE_KEY" })
-- print("Logged in user:", app.user_data.username)
-- print("Expires at:", app.user_data.expires)

-- Example 2: Authenticate with Username and Password
-- app:login({ username = "username", password = "password" })
-- print("Logged in user:", app.user_data.username)
