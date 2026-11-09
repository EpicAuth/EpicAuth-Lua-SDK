local function resolve()
    local ok, mod = pcall(require, "epicauth.init")
    if ok then return mod end

    local script_dir = (debug and debug.getinfo and debug.getinfo(1, "S").source:match("^@?(.*[/\\])")) or ""
    if script_dir ~= "" then
        package.path = script_dir .. "src/?.lua;" .. script_dir .. "src/?/init.lua;" .. package.path
    else
        package.path = "./src/?.lua;./src/?/init.lua;" .. package.path
    end

    local ok2, mod2 = pcall(require, "epicauth")
    if ok2 then return mod2 end

    return require("src.epicauth.init")
end

return resolve()
