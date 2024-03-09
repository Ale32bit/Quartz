local quartz, ui

local function keyControls()
    while true do
        local ev = { os.pullEvent() }
        if ui.active then
            if ev[1] == "key" then
                local key = ev[2]
                if key == keys.space then
                    if quartz.track then
                        if quartz.track:getState() == "paused" then
                            quartz.log("Play")
                            quartz.track:play()
                        else
                            quartz.log("Pause")
                            quartz.track:pause()
                        end
                    else
                        quartz.loadDriver()
                    end
                elseif key == keys.s then
                    if quartz.track then
                        quartz.log("Stop")
                        quartz.track:stop()
                    end
                elseif key == keys.right then
                    if quartz.track then
                        quartz.log("Forward 5 seconds")
                        local pos = quartz.track:getPosition()
                        quartz.track:setPosition(pos + 5)
                    end
                elseif key == keys.left then
                    if quartz.track then
                        quartz.log("Backward 5 seconds")
                        local pos = quartz.track:getPosition()
                        quartz.track:setPosition(pos - 5)
                    end
                elseif key == keys.up then
                    local volume = quartz.speakers.volume + 0.05
                    quartz.setVolume(volume)
                    quartz.log("Volume:", quartz.speakers.volume * 100)
                elseif key == keys.down then
                    local volume = quartz.speakers.volume - 0.05
                    quartz.setVolume(volume)
                    quartz.log("Volume:", quartz.speakers.volume * 100)
                elseif key == keys.pageUp then
                    local distance = quartz.speakers.distance + 1
                    quartz.setDistance(distance)
                    quartz.log("Distance:", quartz.speakers.distance)
                elseif key == keys.pageDown then
                    local distance = quartz.speakers.distance - 1
                    quartz.setDistance(distance)
                    quartz.log("Distance:", quartz.speakers.distance)
                end
            end
        end
    end
end

local function formatSeconds(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local progressBar
local progressTime
local function updateProgressBar()
    if progressBar then
        local length, currentPos
        if quartz.track and not quartz.track.disposed then
            length = quartz.trackMeta.length
            currentPos = quartz.track:getPosition()
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

local function progressBarTask()
    while true do
        updateProgressBar()
        sleep(0.2)
    end
end

local function guiControls()
    local w, h = quartz.guiWindow.getSize()
    quartz.guiWindow.clear()
    ui:label(1, h, "Q " .. quartz.version, {
        text = colors.gray
    })

    ui:label(1, 1, "GUI WIP")

    local exitButton = ui:button(w, 1, "x", {
        w = 1,
        buttonBg = colors.black,
        buttonFg = colors.red,
        buttonBgActive = colors.red,
        buttonFgActive = colors.white,
    })
    exitButton.onclick = function(self)
        quartz.exit()
    end

    local artistLabel = ui:centerLabel(1, 4, w, "");
    local titleLabel = ui:centerLabel(1, 6, w, "No disk");
    local albumLabel = ui:centerLabel(1, 9, w, "Insert a disk with an audio track", {
        text = colors.lightGray
    });

    progressTime = ui:centerLabel(1, h - 7, w, "00:00 - 00:00")
    progressBar = ui:progress(2, h - 5, w - 2, 0)

    progressBar.onclick = function(self, level)
        if quartz.track then
            local at = quartz.trackMeta.length * level
            quartz.track:setPosition(at)
        end
    end

    local centerX = math.floor(w / 2)
    local baseline = h - 1

    local playButton = ui:button(centerX - 1, baseline - 2, "\x10", {
        w = 5, h = 3
    })
    playButton.onclick = function(self)
        if quartz.track then
            if quartz.track:getState() == "paused" then
                quartz.log("Resuming track")
                quartz.track:play()
            else
                quartz.log("Pausing track")
                quartz.track:pause()
            end
        else
            quartz.loadDriver()
        end
    end

    local forwardButton = ui:button(centerX + 5, baseline, "\x10\x10")
    local backwardButton = ui:button(centerX - 6, baseline, "\x11\x11")

    forwardButton.onclick = function(self)
        if quartz.track then
            quartz.log("Forward 5 seconds")
            local pos = quartz.track:getPosition()
            quartz.track:setPosition(pos + 5)
        end
    end

    backwardButton.onclick = function(self)
        if quartz.track then
            quartz.log("Backward 5 seconds")
            local pos = quartz.track:getPosition()
            quartz.track:setPosition(pos - 5)
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
        elseif ev[1] == "quartz_load" then
            local meta = ev[2]
            artistLabel.setText(meta.artist)
            titleLabel.setText(meta.title)
            albumLabel.setText(meta.album)
        elseif ev[1] == "quartz_dispose" then
            artistLabel.setText("")
            titleLabel.setText("No disk")
            albumLabel.setText("Insert a disk with an audio track")
        end
    end
end

local function init(q)
    quartz = q
    ui = quartz.ui

    quartz.addTask(keyControls)
    quartz.addTask(guiControls)
    quartz.addTask(progressBarTask)
    quartz.addTask(function()
        sleep(1)
        quartz.switchToGuiScreen()
    end)
end

return init
