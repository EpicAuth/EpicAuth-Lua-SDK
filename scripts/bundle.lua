#!/usr/bin/env lua
-- ==============================================================================
-- EpicAuth Lua SDK - Standalone Single-File Bundler
-- Bundles src/epicauth/* modules into a zero-dependency distribution file.
--
-- Usage:
--   lua scripts/bundle.lua [--output <path>] [--no-verify]
-- ==============================================================================

local MODULE_DEFS = {
    { name = "epicauth.errors", path = "src/epicauth/errors.lua" },
    { name = "epicauth.json",   path = "src/epicauth/json.lua" },
    { name = "epicauth.crypto", path = "src/epicauth/crypto.lua" },
    { name = "epicauth.hwid",   path = "src/epicauth/hwid.lua" },
    { name = "epicauth.http",   path = "src/epicauth/http.lua" },
    { name = "epicauth.client", path = "src/epicauth/client.lua" },
    { name = "epicauth.init",   path = "src/epicauth/init.lua" },
}

local function read_file(filepath)
    local f = io.open(filepath, "rb")
    if not f then
        error(string.format("Could not open source module at '%s'", filepath))
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function ensure_directory(path)
    local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
        or (os.getenv and (os.getenv("OS") or ""):find("Windows") ~= nil)
    if is_windows then
        os.execute(string.format('mkdir "%s" 2>nul', path:gsub("/", "\\")))
    else
        os.execute(string.format('mkdir -p "%s" 2>/dev/null', path))
    end
end

local function write_file(filepath, content)
    local dir = filepath:match("^(.*)[/\\][^/\\]+$")
    if dir and #dir > 0 then
        ensure_directory(dir)
    end
    local f = io.open(filepath, "wb")
    if not f then
        error(string.format("Failed to open '%s' for writing", filepath))
    end
    f:write(content)
    f:close()
end

local function get_version()
    local ok, p = pcall(io.popen, 'ls epicauth-*.rockspec 2>/dev/null || dir /b epicauth-*.rockspec 2>nul')
    local rockspec_file = nil
    if ok and p then
        for line in p:lines() do
            local clean = line:gsub("%s+$", "")
            if clean:find("^epicauth%-[%d%.]+%-%d+%.rockspec$") then
                rockspec_file = clean
                break
            end
        end
        p:close()
    end

    if rockspec_file then
        local content = read_file(rockspec_file)
        local ver = content:match('version%s*=%s*"([%d%.]+)%-%d+"')
        if ver then return ver end
    end

    local f = io.open("epicauth-1.0.3-1.rockspec", "r")
    if f then
        local c = f:read("*a")
        f:close()
        local ver = c:match('version%s*=%s*"([%d%.]+)%-%d+"')
        if ver then return ver end
    end

    return "1.0.3"
end

local function build_bundle(output_path)
    local version = get_version()
    print(string.format("[EpicAuth Bundler] Packaging SDK v%s into '%s'...", version, output_path))

    local out = {}
    local function append(str)
        table.insert(out, str)
    end

    append("--[==[\n")
    append("================================================================================\n")
    append("EpicAuth Lua SDK - Standalone Single-File Distribution Bundle\n")
    append(string.format("Version:  %s\n", version))
    append("Homepage: https://epicauth.cc\n")
    append("License:  Elastic License 2.0\n")
    append("\n")
    append("This standalone bundle contains all official EpicAuth SDK modules packaged into\n")
    append("a single zero-dependency file for use in embedded runtimes, game engines\n")
    append("(Roblox, FiveM, GameGuardian), plugin sandboxes, and environments without LuaRocks.\n")
    append("\n")
    append("USAGE MODES:\n")
    append("  1. Direct file load (sandboxes):\n")
    append('     local EpicAuth = dofile("epicauth.bundle.lua")\n')
    append("  2. Evaluated load:\n")
    append('     local EpicAuth = loadfile("epicauth.bundle.lua")()\n')
    append("  3. Standard module require (when in package.path):\n")
    append('     local EpicAuth = require("epicauth.bundle")\n')
    append("\n")
    append("INITIALIZATION:\n")
    append("  local app = EpicAuth.new({\n")
    append('      name = "YourApplicationName",\n')
    append('      ownerid = "YOUR_OWNER_ID",\n')
    append('      version = "1.0",\n')
    append("      exitOnError = false -- recommended for game servers/sandboxes\n")
    append("  })\n")
    append("  app:init()\n")
    append("================================================================================\n")
    append("--]==]\n\n")

    append("return (function(...)\n")
    append("    local _ENV = _ENV\n")
    append("    local _G = _G or (_ENV and _ENV._G) or {}\n")
    append("    local _modules = {}\n")
    append("    local _loaded = {}\n\n")

    append("    -- Custom isolated require wrapper for strict sandboxed runtimes\n")
    append("    local function _custom_require(modname)\n")
    append('        if type(modname) ~= "string" then\n')
    append('            error("module name must be a string", 2)\n')
    append("        end\n\n")
    append("        local canonical = modname\n")
    append('        if canonical:sub(1, 13) == "src.epicauth." then\n')
    append('            canonical = "epicauth." .. canonical:sub(14)\n')
    append('        elseif canonical == "src.epicauth" or canonical == "epicauth.bundle" then\n')
    append('            canonical = "epicauth"\n')
    append("        end\n\n")
    append('        if not _modules[canonical] and _modules["epicauth." .. canonical] then\n')
    append('            canonical = "epicauth." .. canonical\n')
    append("        end\n\n")
    append('        if canonical == "epicauth" then\n')
    append('            canonical = "epicauth.init"\n')
    append("        end\n\n")
    append("        if _loaded[canonical] ~= nil then\n")
    append("            return _loaded[canonical]\n")
    append("        end\n\n")
    append("        local loader = _modules[canonical]\n")
    append("        if loader then\n")
    append("            local res = loader(_custom_require, _loaded)\n")
    append("            if res == nil then res = true end\n")
    append("            _loaded[canonical] = res\n")
    append("            return res\n")
    append("        end\n\n")
    append('        local glob_req = rawget(_G, "require")\n')
    append('        if type(glob_req) == "function" and glob_req ~= _custom_require then\n')
    append("            return glob_req(modname)\n")
    append("        end\n\n")
    append('        error(string.format("module \'%s\' not found in EpicAuth bundle", tostring(modname)), 2)\n')
    append("    end\n\n")

    append("    -- Register module loaders in package.preload if available\n")
    append('    if type(package) == "table" and type(package.preload) == "table" then\n')
    append("        local preload = package.preload\n")
    append('        preload["epicauth"] = function() return _custom_require("epicauth.init") end\n')
    append('        preload["epicauth.bundle"] = function() return _custom_require("epicauth.init") end\n')
    append('        preload["epicauth.init"] = function() return _custom_require("epicauth.init") end\n')
    append('        preload["epicauth.client"] = function() return _custom_require("epicauth.client") end\n')
    append('        preload["epicauth.crypto"] = function() return _custom_require("epicauth.crypto") end\n')
    append('        preload["epicauth.errors"] = function() return _custom_require("epicauth.errors") end\n')
    append('        preload["epicauth.http"] = function() return _custom_require("epicauth.http") end\n')
    append('        preload["epicauth.hwid"] = function() return _custom_require("epicauth.hwid") end\n')
    append('        preload["epicauth.json"] = function() return _custom_require("epicauth.json") end\n')
    append("    end\n\n")

    for _, mod in ipairs(MODULE_DEFS) do
        local raw = read_file(mod.path)
        append("    ----------------------------------------------------------------------------\n")
        append(string.format("    -- Module: %s (%s)\n", mod.name, mod.path))
        append("    ----------------------------------------------------------------------------\n")
        append(string.format('    _modules["%s"] = function(require, _LOADED)\n', mod.name))
        append(raw)
        if raw:sub(-1) ~= "\n" then append("\n") end
        append("    end\n\n")
    end

    append("    -- Export the root EpicAuth SDK module\n")
    append('    return _custom_require("epicauth.init")\n')
    append("end)(...)\n")

    local bundle_content = table.concat(out)
    write_file(output_path, bundle_content)
    print(string.format("[EpicAuth Bundler] Successfully wrote %d bytes (%d modules) to '%s'", #bundle_content, #MODULE_DEFS, output_path))
    return output_path
end

local output_target = "dist/epicauth.bundle.lua"
local do_verify = true

local i = 1
local arg_list = arg or {}
while i <= #arg_list do
    if arg_list[i] == "--output" or arg_list[i] == "-o" then
        output_target = arg_list[i + 1] or output_target
        i = i + 1
    elseif arg_list[i] == "--no-verify" then
        do_verify = false
    end
    i = i + 1
end

local target_file = build_bundle(output_target)

if do_verify and type(loadfile) == "function" then
    print("[EpicAuth Bundler] Verifying bundle integrity...")
    local chunk, err = loadfile(target_file)
    if not chunk then
        error("Bundle syntax validation failed: " .. tostring(err))
    end
    local ok, EpicAuth = pcall(chunk)
    if not ok or type(EpicAuth) ~= "table" then
        error("Bundle execution validation failed: " .. tostring(EpicAuth))
    end
    if type(EpicAuth.new) ~= "function" then
        error("Bundle export validation failed: EpicAuth.new is missing")
    end
    print("[EpicAuth Bundler] Bundle verified successfully! Exports EpicAuth.")
end
