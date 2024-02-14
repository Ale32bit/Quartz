--[[
    Quartz Player (c) AlexDevs
    https://alexdevs.me
    https://github.com/Ale32bit/Quartz

    MIT License
    https://github.com/Ale32bit/Quartz/blob/main/LICENSE
]]

print("Quartz Player 0.0.3")


settings.define("quartz.right", {
    description = "Right speaker",
    default = "right",
    type = "string",
})

settings.define("quartz.left", {
    description = "Left speaker",
    default = "left",
    type = "string",
})

settings.define("quartz.drivers", {
    description = "Directory path of playback driver files",
    default = "/lib/drivers",
    type = "string",
})

settings.define("quartz.autoplay", {
    description = "Autoplay the track on start",
    default = true,
    type = "boolean",
})

settings.define("quartz.volume", {
    description = "Default audio volume. Range: 0.0 - 1.0",
    default = 1,
    type = "number"
})

settings.define("quartz.distance", {
    description = "Default audio distance. Range: 0 - 128",
    default = 1,
    type = "number"
})

settings.define("quartz.loop", {
    description = "Restart track when it ends",
    default = true,
    type = "boolean"
})

local drive = peripheral.find("drive")

if not drive then
    error("Missing disk drive", 0)
end

local speakers = {
    left = peripheral.wrap(settings.get("quartz.left")),
    right = peripheral.wrap(settings.get("quartz.right")),
}

speakers.left = speakers.left or speakers.right
speakers.right = speakers.right or speakers.left
speakers.isMono = speakers.left == speakers.right
speakers.volume = settings.get("quartz.volume")
speakers.distance = settings.get("quartz.distance")

if not speakers.left and not speakers.right then
    error("Speakers not found", 0)
end

print("Speaker configuration:", speakers.isMono and "mono" or "stereo")

print("Loading playback drivers...")

local drivers = {}

for i, fileName in ipairs(fs.list(settings.get("quartz.drivers"))) do
    local file = fileName:gsub("%.lua$", "")
    local path = fs.combine(settings.get("quartz.drivers"), file):gsub("/", ".")

    local driver = require(path)
    drivers[driver.type] = driver
    print("Found driver:", driver.type)
end

local tasks = {}
local filters = {}
local function addTask(func)
    local thread = coroutine.create(func)
    tasks[#tasks + 1] = thread
    return thread
end

local function killTask(pid)
    tasks[pid] = nil
    filters[pid] = nil
end

local track
local trackPid
local trackMeta
local function play()
    print(string.format("Playing %s - %s", trackMeta.artist, trackMeta.title))
    track:play()
end

local function stop(dispose)
    if track then
        print("Stopping playback")
        track:stop()
        if dispose then
            print("Disposing playback")
            track = nil
            pcall(function() track:dispose() end)
            killTask(trackPid)
        end
    end
end

local function loadTrack(tr)
    if track then
        stop(true)
    end
    track = tr
    trackMeta = track:getMeta()

    print(string.format("[%s] Loaded track: %s - %s (%s)",
        track.type, trackMeta.artist, trackMeta.title, trackMeta.album))

    trackPid = addTask(function()
        track:run()
    end)

    play()
end

local function setVolume(vol)
    if vol > 1 then
        vol = 1
    end
    if vol < 0 then
        vol = 0
    end
    speakers.volume = vol
    os.queueEvent("quartz_volume", vol)
end

local function setDistance(dist)
    if dist > 128 then
        dist = 128
    end
    if dist < 0 then
        dist = 0
    end
    speakers.distance = dist
    os.queueEvent("quartz_distance", dist)
end

local function loadDriver()
    local compatibleDrivers = {}

    for _, driver in pairs(drivers) do
        local isCompatible, weight = driver.checkCompatibility(drive)
        if isCompatible then
            table.insert(compatibleDrivers, {
                driver = driver,
                weight = weight,
            })
        end
    end

    table.sort(compatibleDrivers, function(a, b)
        return a.weight > b.weight
    end)

    local comp = compatibleDrivers[1]
    if comp then
        local track = comp.driver.new(drive, speakers)
        loadTrack(track)
    else
        printError("No eligible driver found")
    end
end

addTask(function()
    print("Ready")
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "disk" and ev[2] == peripheral.getName(drive) then
            -- This event is fired on startup, somehow, without interacting with the drive
            if os.clock() > 0.1 then
                loadDriver()
            end
        elseif ev[1] == "disk_eject" then
            stop(true)
        elseif ev[1] == "quartz_driver_end" then
            if settings.get("quartz.loop") then
                loadDriver()
            end
        end
    end
end)

addTask(function()
    if settings.get("quartz.autoplay") then
        loadDriver()
    end

    print("CONTROLS")
    print(" - SPACE: Play/Pause")
    print(" - S: Stop")
    print(" - Right: Forward 5 seconds")
    print(" - Left: Backward 5 seconds")
    print(" - Up: Volume up 1")
    print(" - Down: Volume down 1")
    print(" - PgUp: Distance up 1")
    print(" - DgDn: Distance down 1")

    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "key" then
            local key = ev[2]
            if key == keys.space then
                if track then
                    if track:getState() == "paused" then
                        print("Play")
                        track:play()
                    else
                        print("Pause")
                        track:pause()
                    end
                else
                    loadDriver()
                end
            elseif key == keys.s then
                if track then
                    print("Stop")
                    track:stop()
                end
            elseif key == keys.right then
                if track then
                    print("Forward 5 seconds")
                    local pos = track:getPosition()
                    track:setPosition(pos + 5)
                end
            elseif key == keys.left then
                if track then
                    print("Backward 5 seconds")
                    local pos = track:getPosition()
                    track:setPosition(pos - 5)
                end
            elseif key == keys.up then
                local volume = speakers.volume + 0.05
                setVolume(volume)
                print("Volume:", speakers.volume * 100)
            elseif key == keys.down then
                local volume = speakers.volume - 0.05
                setVolume(volume)
                print("Volume:", speakers.volume * 100)
            elseif key == keys.pageUp then
                local distance = speakers.distance + 1
                setDistance(distance)
                print("Distance:", speakers.distance)
            elseif key == keys.pageDown then
                local distance = speakers.distance - 1
                setDistance(distance)
                print("Distance:", speakers.distance)
            end
        end
    end
end)

local event = {}
while true do
    for i, thread in pairs(tasks) do
        if coroutine.status(thread) == "dead" then
            tasks[i] = nil
            filters[i] = nil
        else
            if filters[i] == nil or event[1] == filters[i] or event[1] == "terminate" then
                local ok, par = coroutine.resume(thread, table.unpack(event))

                if ok then
                    filters[i] = par
                else
                    error(par, 0)
                end
            end
        end
    end

    event = table.pack(coroutine.yield())
end
