local uriList = require("quartz.lib.urilist")
local drive = peripheral.find("drive")
local quartz
local w, h
local playlistMode = false

local function resolveUrl(url)
    local streamType = url:match("%.(m?dfpwm)$")
    if not streamType then
        if url:match("%.urilist$") then
            streamType = "urilist"
        else
            local title = url
            if #title >= w - 5 then
                title = title:sub(-(w - 8)) .. "..."
            end
            url = "https://cc.alexdevs.me/mdfpwm?url=" ..
                textutils.urlEncode(url) .. "&title=" .. textutils.urlEncode(title)
            streamType = "mdfpwm"
        end
    end
    return url, streamType
end

local function streamUrilist(list, meta)
    playlistMode = true
    local uri = table.remove(list, 1)
    repeat
        local streamUrl, streamType = resolveUrl(uri)
        if streamType == "mdfpwm" then
            streamUrl = streamUrl ..
            "&album=" .. textutils.urlEncode(meta.album) .. "&artist=" .. textutils.urlEncode(meta.artist)
        end

        local h, err = http.get(streamUrl, nil, true)
        if h then
            quartz.loadDriver(h, "uri." .. streamType)
        end

        os.pullEvent("quartz_driver_end")

        uri = table.remove(list, 1)
    until uri == nil
    playlistMode = false
end

local function tryLoadDriveTrack()
    if not drive then
        return
    end

    if not drive.hasData() then
        return
    end

    local diskPath = drive.getMountPath()
    for i, file in ipairs(fs.list(diskPath)) do        
        local handle = fs.open(fs.combine(diskPath, file), "rb")

        if file:match("%.urilist$") then
            local list, meta = uriList.parse(handle.readAll())
            handle.close()

            quartz.addTask(function()
                streamUrilist(list, meta)
            end)
            return
        end

        if quartz.loadDriver(handle, file, "diskDrive") then
            return
        end
    end
end

local function driveLoader()
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "disk" then
            drive = peripheral.wrap(ev[2])
            -- This event is fired on startup, somehow, without interacting with the drive
            -- doesn't happen in later versions
            if os.clock() > 1 then
                tryLoadDriveTrack()
            end
        elseif ev[1] == "disk_eject" and quartz.trackSource == "diskDrive" and drive and ev[2] == peripheral.getName(drive) then
            quartz.stop(true)
        elseif ev[1] == "quartz_driver_end" and not playlistMode then
            if settings.get("quartz.loop") and quartz.trackSource == "diskDrive" and drive then
                tryLoadDriveTrack()
            end
        end
    end
end

local function init(q)
    quartz = q
    w, h = quartz.termWindow.getSize()

    quartz.addTask(driveLoader)
    quartz.addTask(function()
        sleep(1)
        if settings.get("quartz.autoplay") then
            tryLoadDriveTrack()
        end
    end)
end

return init
