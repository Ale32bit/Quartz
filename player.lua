--[[
    Quartz Player by AlexDevs

    Quartz Player (c) 2024 AlexDevs
]]

print("Quartz Player 0.0.1")


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
speakers.volume = 1
speakers.distance = 1

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

    print(string.format("[%s] Loaded track: %s - %s (%s)", track.type, trackMeta.artist, trackMeta.title, trackMeta
    .album))

    trackPid = addTask(function()
        track:run()
    end)

    play()
end

local function setVolume(vol)
    speakers.volume = vol
    os.queueEvent("quartz_volume", vol)
end

local function setDistance(dist)
    speakers.distance = dist
    os.queueEvent("quartz_distance", dist)
end

addTask(function()
    print("Ready")
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "disk" and ev[2] == peripheral.getName(drive) then
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
        elseif ev[1] == "disk_eject" then
            stop(true)
        end
    end
end)

addTask(function()

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
            if track then
                if key == keys.space then
                    if track:getState() == "paused" then
                        print("Play")
                        track:play()
                    else
                        print("Pause")
                        track:pause()
                    end
                elseif key == keys.s then
                    print("Stop")
                    track:stop()
                elseif key == keys.right then
                    print("Forward 5 seconds")
                    local pos = track:getPosition()
                    track:setPosition(pos + 5)
                elseif key == keys.left then
                    print("Backward 5 seconds")
                    local pos = track:getPosition()
                    track:setPosition(pos - 5)
                elseif key == keys.up then
                    local volume = speakers.volume + 0.05
                    if volume > 1 then
                        volume = 1
                    end
                    setVolume(volume)
                    print("Volume:", speakers.volume * 100)
                elseif key == keys.down then
                    local volume = speakers.volume - 0.05
                    if volume < 0 then
                        volume = 0
                    end
                    setVolume(volume)
                    print("Volume:", speakers.volume * 100)
                elseif key == keys.pageUp then
                    local distance = speakers.distance + 1
                    if distance > 128 then
                        distance = 128
                    end

                    setDistance(distance)
                    print("Distance:", speakers.distance)
                elseif key == keys.pageDown then
                    local distance = speakers.distance - 1
                    if distance < 0 then
                        distance = 0
                    end

                    setDistance(distance)
                    print("Distance:", speakers.distance)
                end
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
