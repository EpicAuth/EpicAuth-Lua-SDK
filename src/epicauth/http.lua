local http = {}

function http.url_encode(str)
    if type(str) ~= "string" then str = tostring(str) end
    return (str:gsub("[^%w%-%._~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

function http.build_query(params)
    local parts = {}
    for k, v in pairs(params) do
        if v ~= nil then
            table.insert(parts, http.url_encode(tostring(k)) .. "=" .. http.url_encode(tostring(v)))
        end
    end
    return table.concat(parts, "&")
end

function http.post(url, post_data_str, custom_handler)
    if type(custom_handler) == "function" then
        return custom_handler(url, { ["Content-Type"] = "application/x-www-form-urlencoded" }, post_data_str)
    end

    local game_obj = rawget(_G, "game")
    if type(game_obj) == "userdata" or type(game_obj) == "table" then
        local ok, http_svc = pcall(function() return game_obj:GetService("HttpService") end)
        if ok and http_svc and http_svc.RequestAsync then
            local resp = http_svc:RequestAsync({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
                Body = post_data_str
            })
            local h = {}
            if resp.Headers then
                for k, v in pairs(resp.Headers) do
                    h[k:lower()] = v
                end
            end
            return { status = resp.StatusCode or 200, body = resp.Body or "", headers = h }
        end
    end

    local gg = rawget(_G, "gg")
    if type(gg) == "table" and type(gg.makeRequest) == "function" then
        local res = gg.makeRequest(url, { ["Content-Type"] = "application/x-www-form-urlencoded" }, post_data_str)
        if res then
            local h = {}
            if type(res.headers) == "table" then
                for k, v in pairs(res.headers) do
                    local val = type(v) == "table" and v[1] or v
                    h[tostring(k):lower()] = tostring(val)
                end
            end
            return {
                status = tonumber(res.code) or 200,
                body = res.content or "",
                headers = h
            }
        end
    end

    local has_ssl, https = pcall(require, "ssl.https")
    local has_ltn12, ltn12 = pcall(require, "ltn12")
    if has_ssl and has_ltn12 and type(https.request) == "function" then
        local resp_body = {}
        local _, code, resp_headers = https.request({
            url = url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["Content-Length"] = tostring(#post_data_str)
            },
            source = ltn12.source.string(post_data_str),
            sink = ltn12.sink.table(resp_body)
        })
        local h = {}
        if type(resp_headers) == "table" then
            for k, v in pairs(resp_headers) do
                h[k:lower()] = v
            end
        end
        return { status = tonumber(code) or 200, body = table.concat(resp_body), headers = h }
    end

    if type(io.popen) == "function" then
        local is_windows = (package.config:sub(1, 1) == "\\")
        local tmp_dir = os.getenv("TEMP") or os.getenv("TMP") or (is_windows and "." or "/tmp")
        local tmp_file = string.format("%s/epicauth_%d_%d.tmp", tmp_dir, os.time(), math.random(1000, 9999))
        local f = io.open(tmp_file, "wb")
        if f then
            f:write(post_data_str)
            f:close()
        end

        local cmd = string.format('curl -s -i -X POST "%s" --data-binary "@%s"', url, tmp_file)
        if is_windows then
            cmd = string.format('curl.exe -s -i -X POST "%s" --data-binary "@%s"', url, tmp_file)
        end

        local handle = io.popen(cmd, "r")
        if handle then
            local raw = handle:read("*a")
            handle:close()
            pcall(os.remove, tmp_file)

            if raw and #raw > 0 then
                local header_part, body_part = raw:match("^(.-)\r?\n\r?\n(.*)$")
                if not header_part then
                    header_part = ""
                    body_part = raw
                end

                local headers_map = {}
                for line in header_part:gmatch("[^\r\n]+") do
                    local k, v = line:match("^([^:]+)%s*:%s*(.*)$")
                    if k and v then
                        headers_map[k:lower()] = v:gsub("%s+$", "")
                    end
                end

                local status = tonumber(header_part:match("^HTTP/%d+%.?%d*%s+(%d+)")) or 200
                return { status = status, body = body_part or "", headers = headers_map }
            end
        end
        pcall(os.remove, tmp_file)
    end

    error("No supported HTTP transport available. Provide options.http_handler or install LuaSec/curl.")
end

return http
