local uriList = require("quartz.lib.urilist")
local quartz
local playlistMode = false
local moduleUrilist

local module = {
    drive = peripheral.find("drive")
}

local function tryLoadDriveTrack()
    if not module.drive then
        return
    end

    if not module.drive.hasData() then
        return
    end

    local diskPath = module.drive.getMountPath()
    for i, file in ipairs(fs.list(diskPath)) do        
        local handle = fs.open(fs.combine(diskPath, file), "rb")

        if file:match("%.urilist$") and moduleUrilist and moduleUrilist.playUrilist then
            local list, meta = uriList.parse(handle.readAll())
            handle.close()

            quartz.addTask(function()
                moduleUrilist.playUrilist(list, meta)
            end)
            return
        end

        local altMeta = {}
        local diskLabel = module.drive.getDiskLabel()
        if diskLabel then
            altMeta.artist, altMeta.title, altMeta.album = diskLabel:match("^(.+)%s*%-%s*(.+)%s*%((.+)%)$")
            if not altMeta.artist then
                altMeta.artist, altMeta.title = diskLabel:match("^(.+)%s*%-%s*(.+)$")
            end
            if altMeta.artist then
                altMeta.artist = altMeta.artist:gsub("%s+", "")
                altMeta.title = altMeta.title:gsub("%s+", "")
                altMeta.album = altMeta.album and altMeta.album:gsub("%s+", "") or ""
            else
                altMeta.title = diskLabel:gsub("%s+", "")
                altMeta.artist = ""
                altMeta.album = ""
            end
        end

        if quartz.loadDriver(handle, file, "diskDrive", altMeta) then
            return
        end
    end
end

local function driveLoader()
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "disk" then
            module.drive = peripheral.wrap(ev[2])
            -- This event is fired on startup, somehow, without interacting with the drive
            -- doesn't happen in later versions
            if os.clock() > 1 then
                tryLoadDriveTrack()
            end
        elseif ev[1] == "disk_eject" and quartz.trackSource == "diskDrive" and module.drive and ev[2] == peripheral.getName(module.drive) then
            quartz.stop(true)
        elseif ev[1] == "quartz_driver_end" and not playlistMode then
            if settings.get("quartz.loop") and quartz.trackSource == "diskDrive" and module.drive then
                tryLoadDriveTrack()
            end
        end
    end
end

function module.init(context)
    quartz = context
    moduleUrilist = quartz.modules["urilist"]

    quartz.addTask(driveLoader)
    quartz.addTask(function()
        sleep(1)
        if settings.get("quartz.autoplay") then
            tryLoadDriveTrack()
        end
    end)
end

return module