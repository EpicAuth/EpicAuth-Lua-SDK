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

local function normalize_headers(raw_h)
    local h = {}
    if type(raw_h) == "table" then
        for k, v in pairs(raw_h) do
            local val = type(v) == "table" and v[1] or v
            h[tostring(k):lower()] = tostring(val)
        end
    end
    return h
end

function http.post(url, post_data_str, custom_handler)
    if type(custom_handler) == "function" then
        local headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }
        local ok, res, opt2, opt3 = pcall(custom_handler, url, headers, post_data_str)
        if not ok or res == nil then
            local ok2, res2, opt2_2, opt3_2 = pcall(custom_handler, {
                url = url,
                method = "POST",
                headers = headers,
                body = post_data_str
            })
            if ok2 and res2 ~= nil then
                ok, res, opt2, opt3 = ok2, res2, opt2_2, opt3_2
            end
        end

        if not ok then
            error("Custom http_handler failed: " .. tostring(res))
        end

        if type(res) == "string" then
            local status_code = tonumber(opt2) or (type(opt2) == "table" and tonumber(opt3)) or 200
            local raw_h = (type(opt2) == "table" and opt2) or (type(opt3) == "table" and opt3) or {}
            return {
                status = status_code,
                body = res,
                headers = normalize_headers(raw_h)
            }
        elseif type(res) == "table" then
            local status_code = tonumber(res.status or res.statusCode or res.StatusCode or res.code or res.status_code) or
                200
            local body_str = tostring(res.body or res.Body or res.content or res.text or "")
            local raw_h = res.headers or res.Headers or {}
            return {
                status = status_code,
                body = body_str,
                headers = normalize_headers(raw_h)
            }
        end
        return res
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
            local h = normalize_headers(resp.Headers)
            return { status = resp.StatusCode or 200, body = resp.Body or "", headers = h }
        end
    end

    local gg = rawget(_G, "gg")
    if type(gg) == "table" and type(gg.makeRequest) == "function" then
        local res = gg.makeRequest(url, { ["Content-Type"] = "application/x-www-form-urlencoded" }, post_data_str)
        if res then
            return {
                status = tonumber(res.code) or 200,
                body = res.content or "",
                headers = normalize_headers(res.headers)
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
        return {
            status = tonumber(code) or 200,
            body = table.concat(resp_body),
            headers = normalize_headers(
                resp_headers)
        }
    end

    if io and type(io.popen) == "function" and type(io.open) == "function" then
        local is_windows = (package and type(package.config) == "string" and package.config:sub(1, 1) == "\\")
            or (os and type(os.getenv) == "function" and (os.getenv("OS") or ""):find("Windows") ~= nil)
        local tmp_dir = (os and type(os.getenv) == "function" and (os.getenv("TEMP") or os.getenv("TMP"))) or
            (is_windows and "." or "/tmp")
        local ostime = (os and type(os.time) == "function" and os.time()) or 0
        local tmp_file = string.format("%s/epicauth_%d_%d.tmp", tmp_dir, ostime, math.random(1000, 9999))
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
