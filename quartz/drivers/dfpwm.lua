local make_decoder

local driverType = "dfpwm"

local Track = {}



local function playAudio(speakers, sample)
    if speakers.distributedMode then
        local ok = true
        for i, speaker in ipairs(speakers.distributedSpeakers) do
            ok = ok and speaker.playAudio(sample, speakers.distance)
        end
        return ok
    end

    if #sample == 0 then
        return
    end

    if speakers.isMono then
        return speakers.left.playAudio(sample, speakers.distance)
    end

    return speakers.left.playAudio(sample, speakers.distance) and speakers.right.playAudio(sample, speakers.distance)
end

local function stopAudio(speakers)
    if speakers.distributedMode then
        for i, speaker in ipairs(speakers.distributedSpeakers) do
            speaker.stop()
        end
        return
    end

    speakers.left.stop()
    if speakers.isMono then
        return
    end
    speakers.right.stop()
end

function Track:run()
    while not self.disposed do
        while self.state == "paused" do
            os.pullEvent("quartz_play")
        end
        local chunk = self.data:sub((self.position + 1), self.position + self.blockSize)
        if chunk and chunk ~= "" then
            local sample = self.decoder(chunk, self.speakers.volume)
            while self.state ~= "paused" and not self.disposed and not playAudio(self.speakers, sample) do
                os.pullEvent("speaker_audio_empty")
            end
            self.position = self.position + self.blockSize
        else
            os.pullEvent("speaker_audio_empty")
            sleep(0.5)
            self:stop()
            os.queueEvent("quartz_driver_end")
        end
    end
end

function Track:getMeta()
    return {
        artist = self.altMeta.artist or "Unknown artist",
        title = self.altMeta.title or "Unknown title",
        album = self.altMeta.album or "Unknown album",
        size = self.size,
        length = self.size / 6000,
    }
end

function Track:getState()
    return self.state
end

function Track:getPosition()
    return self.position / 6000
end

function Track:setPosition(pos)
    if pos < 0 then
        pos = 0
    end
    self.position = pos * 6000
    local wasPaused = self.state == "paused"
    self:pause()
    self.decoder = make_decoder()
    if not wasPaused then
        self:play()
    end
end

function Track:play()
    self.state = "running"
    os.queueEvent("speaker_audio_empty")
    os.queueEvent("quartz_play")
end

function Track:pause()
    self.state = "paused"
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
end

function Track:stop()
    self.state = "paused"
    self.position = 0
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
end

function Track:dispose()
    self.disposed = true
end

local function new(handle, name, speakers, decoder, altMeta)
    make_decoder = decoder
    local data = handle.readAll()
    handle.close()
    local size = #data

    local track = {
        state = "paused",
        data = data,
        blockSize = 6000,
        position = 0,
        type = driverType,
        decoder = decoder(),
        speakers = speakers,
        size = size,
        disposed = false,
        altMeta = altMeta or {},
    }

    setmetatable(track, { __index = Track })
    return track
end

local function checkCompatibility(handle, name)
    return handle and name:match("%.dfpwm"), 10
end

return {
    new = new,
    type = driverType,
    checkCompatibility = checkCompatibility,
}
