--[[
    Quartz Player (c) AlexDevs
    https://alexdevs.me
    https://github.com/Ale32bit/Quartz

    Apache License 2.0
    https://github.com/Ale32bit/Quartz/blob/main/LICENSE
]]

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

local running = true

local w, h = term.getSize()
local current = term.current()
local logWindow = window.create(current, 1, 1, w, h, true)
local guiWindow = window.create(current, 1, 1, w, h, false)
local function log(...)
    local oldTerm = term.redirect(logWindow)
    print(...)
    term.redirect(oldTerm)
end
local function logError(...)
    local oldTerm = term.redirect(logWindow)
    printError(...)
    term.redirect(oldTerm)
end

local function switchToLogScreen()
    term.redirect(logWindow)
    guiWindow.setVisible(false)
    logWindow.setVisible(true)
    logWindow.redraw()
end

local function switchToGuiScreen()
    term.redirect(guiWindow)
    guiWindow.setVisible(true)
    logWindow.setVisible(false)
    guiWindow.redraw()
end

local version = "0.1.0"

log("Quartz Player " .. version .. " by AlexDevs")
log("https://github.com/Ale32bit/Quartz")

local UI = require("lib.ui")
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

log("Speaker configuration:", speakers.isMono and "mono" or "stereo")
speakers.left.stop()
speakers.right.stop()

log("Loading playback drivers...")

local drivers = {}

for i, fileName in ipairs(fs.list(settings.get("quartz.drivers"))) do
    local file = fileName:gsub("%.lua$", "")
    local path = fs.combine(settings.get("quartz.drivers"), file):gsub("/", ".")

    local driver = require(path)
    drivers[driver.type] = driver
    log("Found driver:", driver.type)
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

local ui = UI(guiWindow, addTask)

local track
local trackPid
local trackMeta
local function play()
    log(string.format("Playing %s - %s", trackMeta.artist, trackMeta.title))
    track:play()
end

local function stop(dispose)
    if track then
        log("Stopping playback")
        track:stop()
        if dispose then
            log("Disposing playback")
            pcall(function() track:dispose() end)
            track = nil
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

    log(string.format("[%s] Loaded track: %s - %s (%s)",
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
        logError("No eligible driver found")
    end
end

local function exit()
    running = false
    guiWindow.setVisible(false)
    stop(true)
    term.redirect(current)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

addTask(function()
    log("Ready")
    log("Press F1 to toggle this screen")
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "disk" and ev[2] == peripheral.getName(drive) then
            -- This event is fired on startup, somehow, without interacting with the drive
            -- doesn't happen in later versions
            if os.clock() > 1 then
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
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "key" then
            local key = ev[2]
            if key == keys.space then
                if track then
                    if track:getState() == "paused" then
                        log("Play")
                        track:play()
                    else
                        log("Pause")
                        track:pause()
                    end
                else
                    loadDriver()
                end
            elseif key == keys.s then
                if track then
                    log("Stop")
                    track:stop()
                end
            elseif key == keys.right then
                if track then
                    log("Forward 5 seconds")
                    local pos = track:getPosition()
                    track:setPosition(pos + 5)
                end
            elseif key == keys.left then
                if track then
                    log("Backward 5 seconds")
                    local pos = track:getPosition()
                    track:setPosition(pos - 5)
                end
            elseif key == keys.up then
                local volume = speakers.volume + 0.05
                setVolume(volume)
                log("Volume:", speakers.volume * 100)
            elseif key == keys.down then
                local volume = speakers.volume - 0.05
                setVolume(volume)
                log("Volume:", speakers.volume * 100)
            elseif key == keys.pageUp then
                local distance = speakers.distance + 1
                setDistance(distance)
                log("Distance:", speakers.distance)
            elseif key == keys.pageDown then
                local distance = speakers.distance - 1
                setDistance(distance)
                log("Distance:", speakers.distance)
            elseif key == keys.f1 then
                if logWindow.isVisible() then
                    switchToGuiScreen()
                else
                    switchToLogScreen()
                end
            end
        end
    end
end)

addTask(function()
    sleep(1)
    if settings.get("quartz.autoplay") then
        loadDriver()
    end
    switchToGuiScreen()
end)

local function formatSeconds(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local progressBar
local progressTime
local function updateProgressBar()
    if progressBar then
        local length, currentPos
        if track and not track.disposed then
            length = trackMeta.length
            currentPos = track:getPosition()
        else
            length = 0
            currentPos = 0
        end
        local currentSeconds = formatSeconds(currentPos)
        local totalSeconds = formatSeconds(math.ceil(length))
        pcall(progressBar.setLevel, currentPos / math.ceil(length))
        progressTime.setText(string.format("%s - %s", currentSeconds, totalSeconds))
    end
end

addTask(function()
    while true do
        updateProgressBar()
        sleep(0.2)
    end
end)

addTask(function()
    ui:label(1, h, "Q " .. version, {
        text = colors.gray
    })

    ui:label(1,1, "GUI WIP")

    local exitButton = ui:button(w, 1, "x", {
        w = 1,
        buttonBg = colors.black,
        buttonFg = colors.red,
        buttonBgActive = colors.red,
        buttonFgActive = colors.white,
    })
    exitButton.onclick = function(self)
        exit()
    end

    progressTime = ui:centerLabel(1, h - 7, w, "00:00 - 00:00")
    progressBar = ui:progress(2, h - 5, w - 2, 0)

    progressBar.onclick = function(self, level)
        if track then
            local at = trackMeta.length * level
            track:setPosition(at)
        end
    end

    local centerX = math.floor(w / 2)
    local baseline = h - 1

    local playButton = ui:button(centerX - 1, baseline - 2, "\x10", {
        w = 5, h = 3
    })
    playButton.onclick = function(self)
        if track then
            if track:getState() == "paused" then
                log("Resuming track")
                track:play()
            else
                log("Pausing track")
                track:pause()
            end
        else
            loadDriver()
        end
    end

    local forwardButton = ui:button(centerX + 5, baseline, "\x10\x10")
    local backwardButton = ui:button(centerX - 6, baseline, "\x11\x11")

    forwardButton.onclick = function(self)
        if track then
            log("Forward 5 seconds")
            local pos = track:getPosition()
            track:setPosition(pos + 5)
        end
    end

    backwardButton.onclick = function(self)
        if track then
            log("Backward 5 seconds")
            local pos = track:getPosition()
            track:setPosition(pos - 5)
        end
    end

    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "quartz_play" then
            playButton.text = " \x95\x95"
            playButton.redraw()
        elseif ev[1] == "quartz_pause" then
            playButton.text = "\x10"
            playButton.redraw()
        end
    end
end)

local event = {}
while running do
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
