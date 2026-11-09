local function load_internal(name)
    local ok, mod = pcall(require, "epicauth." .. name)
    if ok then return mod end
    ok, mod = pcall(require, "src.epicauth." .. name)
    if ok then return mod end
    return require(name)
end

local client = load_internal("client")
local EpicAuthError = load_internal("errors")

local EpicAuth = client.EpicAuth
EpicAuth.EpicAuth = EpicAuth
EpicAuth.EpicAuthError = EpicAuthError

setmetatable(EpicAuth, {
    __call = function(_, options)
        return EpicAuth.new(options)
    end
})

return EpicAuth
