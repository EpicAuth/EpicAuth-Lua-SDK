local EpicAuthError = {}
EpicAuthError.__index = EpicAuthError

function EpicAuthError.new(message, status)
    local self = setmetatable({}, EpicAuthError)
    self.name = "EpicAuthError"
    self.message = tostring(message or "EpicAuth error")
    self.status = status
    return self
end

function EpicAuthError:__tostring()
    if self.status then
        return string.format("EpicAuthError (%s): %s", tostring(self.status), self.message)
    end
    return string.format("EpicAuthError: %s", self.message)
end

return EpicAuthError
