local quartz = {}
local drive = peripheral.find("drive")

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
        if quartz.loadDriver(handle, file, "diskDrive") then
            return
        end
    end
end

local function driveLoader()
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "disk" and ev[2] == peripheral.getName(drive) then
            -- This event is fired on startup, somehow, without interacting with the drive
            -- doesn't happen in later versions
            if os.clock() > 1 then
                tryLoadDriveTrack()
            end
        elseif ev[1] == "disk_eject" and quartz.trackSource == "diskDrive" then
            quartz.stop(true)
        elseif ev[1] == "quartz_driver_end" then
            if settings.get("quartz.loop") and quartz.trackSource == "diskDrive" then
                tryLoadDriveTrack()
            end
        end
    end
end

local function init(q)
    quartz = q

    quartz.addTask(driveLoader)
    quartz.addTask(function()
        sleep(1)
        if settings.get("quartz.autoplay") then
            tryLoadDriveTrack()
        end
    end)
end

return init