local memoryStream = require("quartz.lib.memorystream")
local quartz
local module = {}

local function resolveUrl(url)
    local streamType = url:match("%.(m?dfpwm)$")
    if not streamType then
        if url:match("%.urilist$") then
            streamType = "urilist"
        else
            url = settings.get("quartz.stream.server") .. "/mdfpwm?url=" ..
                textutils.urlEncode(url) .. "&title=" .. textutils.urlEncode(url)
            streamType = "mdfpwm"
        end
    end
    return url, streamType
end

function module.playUrilist(list, meta)
    for i, uri in ipairs(list) do
        local streamUrl, streamType = resolveUrl(uri)
        if streamType == "mdfpwm" then
            streamUrl = streamUrl ..
                "&album=" .. textutils.urlEncode(meta.album) .. "&artist=" .. textutils.urlEncode(meta.artist)
        end

        local h, err = http.get(streamUrl, nil, true)
        if h then
            local ms = memoryStream(true)
            ms.write(h.readAll())
            ms.seek("set", 0)
            h.close()
            quartz.loadDriver(ms, "uri." .. streamType, "urilist")
        end

        os.pullEvent("quartz_driver_end")
        if quartz.trackSource ~= "urilist" then
            break
        end
    end

    if quartz.trackSource == "urilist" and settings.get("quartz.loop") then
        return module.playUrilist(list, meta)
    end
end

function module.init(context)
    quartz = context
end

return module
