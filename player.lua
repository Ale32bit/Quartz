--[[
    Quartz Player (c) AlexDevs
    https://alexdevs.me
    https://github.com/Ale32bit/Quartz

    GNU GPLv3 License
    https://github.com/Ale32bit/Quartz/blob/main/LICENSE
]]

local emulateSmallTerm = false
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

settings.define("quartz.distributed", {
    description = "Play mono audio from all speakers connected to the network",
    default = false,
    type = "boolean",
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

settings.define("quartz.raw", {
    description = "Play unfiltered audio",
    default = false,
    type = "boolean"
})

local quartz = {
    version = "0.5.0",
    modules = {},
    drivers = {},
    args = table.pack(...),
}

local running = true

local current = term.current()
if emulateSmallTerm then
    term.setBackgroundColor(colors.brown)
    term.clear()
    -- turtle / ni term
    current = window.create(term.current(), 1, 1, 39, 13, true)
end
local w, h = current.getSize()
quartz.logWindow = window.create(current, 1, 1, w, h, true)
quartz.guiWindow = window.create(current, 1, 1, w, h, false)
quartz.termWindow = current

quartz.guiWindow.setCursorPos(1, 1)
quartz.guiWindow.write("Quartz Player " .. quartz.version)
quartz.guiWindow.setCursorPos(1, 2)
quartz.guiWindow.write("GUI not loaded.")
quartz.guiWindow.setCursorPos(1, 3)
quartz.guiWindow.write("Press F1 to switch to log screen.")

function quartz.log(...)
    local oldTerm = term.redirect(quartz.logWindow)
    print(...)
    term.redirect(oldTerm)
end

function quartz.logError(...)
    local oldTerm = term.redirect(quartz.logWindow)
    printError(...)
    term.redirect(oldTerm)
end

function quartz.switchToLogScreen()
    term.redirect(quartz.logWindow)
    quartz.guiWindow.setVisible(false)
    quartz.logWindow.setVisible(true)
    quartz.logWindow.redraw()
end

function quartz.switchToGuiScreen()
    term.redirect(quartz.guiWindow)
    quartz.guiWindow.setVisible(true)
    quartz.logWindow.setVisible(false)
    quartz.guiWindow.redraw()
end

quartz.log("Quartz Player " .. quartz.version .. " by AlexDevs")
quartz.log("https://github.com/Ale32bit/Quartz")

local UI = require("quartz.lib.ui")
local dfpwm = require("cc.audio.dfpwm")
local rawDfpwm = require("quartz.lib.rawDfpwm")

local speakers = {
    left = peripheral.wrap(settings.get("quartz.left")),
    right = peripheral.wrap(settings.get("quartz.right")),
}
quartz.speakers = speakers

speakers.left = speakers.left or speakers.right
speakers.right = speakers.right or speakers.left
speakers.isMono = speakers.left == speakers.right
speakers.volume = settings.get("quartz.volume")
speakers.distance = settings.get("quartz.distance")
speakers.distributedMode = settings.get("quartz.distributed")
speakers.distributedSpeakers = {}
if speakers.distributedMode then
    speakers.distributedSpeakers = { peripheral.find("speaker") }
end

if not speakers.left and not speakers.right and not speakers.distributedMode then
    printError("The configured speakers could not be found.")
    print(
    "Configure the speakers by setting the peripheral names to the settings \"quartz.left\" and/or \"quartz.right\" with the \"set\" command.")
    return
end

if speakers.distributedMode and #speakers.distributedSpeakers == 0 then
    printError("There are no speakers attached to the network.")
    return
end

local mode
if speakers.distributedMode then
    mode = "distributed"
else
    mode = speakers.isMono and "mono" or "stereo"
end

quartz.log("Speaker configuration:", mode)

if speakers.distributedMode then
    for i, speaker in ipairs(speakers.distributedSpeakers) do
        speaker.stop()
    end
else
    speakers.left.stop()
    speakers.right.stop()
end

function quartz.make_decoder()
    if settings.get("quartz.raw") then
        return rawDfpwm.make_raw_decoder()
    end
    return dfpwm.make_decoder()
end

quartz.log("Loading playback drivers...")

local driversPath = "/quartz/drivers"
for i, fileName in ipairs(fs.list(driversPath)) do
    local isValid = fileName:match("%.lua$") ~= nil
    local file = fileName:gsub("%.lua$", "")
    if isValid then
        local path = fs.combine(driversPath, file):gsub("/", ".")

        local driver = require(path)
        quartz.drivers[driver.type] = driver
        quartz.log("Found driver:", driver.type)
    end
end

local modulesPath = "/quartz/modules"
for i, fileName in ipairs(fs.list(modulesPath)) do
    local isValid = fileName:match("%.lua$") ~= nil
    local file = fileName:gsub("%.lua$", "")
    if isValid then
        local path = fs.combine(modulesPath, file):gsub("/", ".")

        local module = require(path)
        quartz.modules[file] = module
        quartz.log("Found module:", file)
    end
end

local tasks = {}
local filters = {}
function quartz.addTask(func)
    local thread = coroutine.create(func)
    local pid = #tasks + 1
    tasks[pid] = thread
    return thread, pid
end

function quartz.killTask(pid)
    if not pid then
        return
    end
    tasks[pid] = nil
    filters[pid] = nil
end

quartz.ui = UI(quartz.guiWindow, quartz.addTask)
quartz.track = nil
quartz.trackMeta = nil
quartz.trackSource = nil
local trackPid = nil

function quartz.play()
    quartz.log(string.format("Playing %s - %s", quartz.trackMeta.artist, quartz.trackMeta.title))
    quartz.track:play()
end

function quartz.stop(dispose)
    if quartz.track then
        quartz.log("Stopping playback")
        quartz.track:stop()
        if dispose then
            quartz.log("Disposing playback")
            pcall(function() quartz.track:dispose() end)
            quartz.track = nil
            quartz.killTask(trackPid)

            os.queueEvent("quartz_dispose")
        end
    end
end

function quartz.loadTrack(tr, src)
    if quartz.track then
        quartz.stop(true)
    end
    quartz.track = tr
    quartz.trackMeta = quartz.track:getMeta()
    quartz.trackSource = src

    quartz.log(string.format("[%s] Loaded track: %s - %s (%s)",
        quartz.track.type, quartz.trackMeta.artist, quartz.trackMeta.title, quartz.trackMeta.album))

    os.queueEvent("quartz_load", quartz.trackMeta, quartz.track, quartz.trackSource)

    trackPid = quartz.addTask(function()
        quartz.track:run()
    end)

    quartz.play()
end

function quartz.setVolume(vol)
    if vol > 1 then
        vol = 1
    end
    if vol < 0 then
        vol = 0
    end
    speakers.volume = vol
    os.queueEvent("quartz_volume", vol)
end

function quartz.setDistance(dist)
    if dist > 128 then
        dist = 128
    end
    if dist < 0 then
        dist = 0
    end
    speakers.distance = dist
    os.queueEvent("quartz_distance", dist)
end

function quartz.loadDriver(handle, name, source)
    if not source then
        if debug and debug.getinfo then
            local debugSource = debug.getinfo(2, "S").source
            source = debugSource:match("/(%w+)%.lua$")
        end
    end

    local compatibleDrivers = {}

    for _, driver in pairs(quartz.drivers) do
        local isCompatible, weight = driver.checkCompatibility(handle, name)
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
        local track = comp.driver.new(handle, name, quartz.speakers, quartz.make_decoder)
        quartz.loadTrack(track, source)
        return true
    end
    return false
end

function quartz.exit()
    running = false
    quartz.guiWindow.setVisible(false)
    quartz.stop(true)
    term.redirect(current)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

quartz.log("Loading modules...")
for name, moduleInit in pairs(quartz.modules) do
    quartz.log("Loading module", name)
    local ok, err = pcall(moduleInit, quartz)
    if not ok then
        quartz.logError(err)
    end
end

quartz.addTask(function()
    while true do
        local ev, key = os.pullEvent("key")
        if key == keys.f1 then
            if quartz.logWindow.isVisible() then
                quartz.switchToGuiScreen()
            else
                quartz.switchToLogScreen()
            end
        end
    end
end)

quartz.log("Ready")
quartz.log("Press F1 to toggle the log screen")

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
                    running = false
                    quartz.exit()
                    print("Quartz has crashed!")
                    print("Version:", quartz.version)
                    printError(debug.traceback(thread, par))
                    -- skip pulling event
                    error()
                end
            end
        end
    end

    event = table.pack(coroutine.yield())
end
