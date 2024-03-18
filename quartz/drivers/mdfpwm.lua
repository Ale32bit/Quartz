local mdfpwm = require("quartz.lib.mdfpwm")
local make_decoder
local mmin, mmax = math.min, math.max

local driverType = "mdfpwm"

local Track = {}

local function clamp(val, min, max)
    return mmax(min, mmin(max, val))
end

local function getAverage(left, right)
    local avg = {}
    for i = 1, #left do
        avg[i] = ((left[i] or right[i]) + (right[i] or left[i])) / 2
    end
    return avg
end

local function adjustVolume(buffer, volume)
    for i = 1, #buffer do
        buffer[i] = clamp(buffer[i] * volume, -128, 127)
    end
end

local function playAudio(speakers, sample)
    adjustVolume(sample.left, speakers.volume)
    adjustVolume(sample.right, speakers.volume)

    if speakers.distributedMode then
        local mono = getAverage(sample.left, sample.right)
        local ok = true
        if #mono > 0 then
            for i, speaker in ipairs(speakers.distributedSpeakers) do
                ok = ok and speaker.playAudio(mono, speakers.distance)
            end
        end
        return ok
    end

    if speakers.isMono then
        return speakers.left.playAudio(getAverage(sample.left, sample.right), speakers.distance)
    end

    local ok = true
    if #sample.left > 0 then
        ok = ok and speakers.left.playAudio(sample.left, speakers.distance)
    end
    if #sample.right > 0 then
        ok = ok and speakers.right.playAudio(sample.right, speakers.distance)
    end

    return ok
end

local function stopAudio(speakers)
    if speakers.distributedMode then
        for i, speaker in ipairs(speakers.distributedSpeakers) do
            speaker.stop()
        end
        return
    end

    speakers.left.stop()
    if not speakers.isMono then
        speakers.right.stop()
    end
end

local function createDecoders()
    return make_decoder(), make_decoder()
end

function Track:run()
    while not self.disposed do
        while self.state == "paused" do
            os.pullEvent("quartz_play")
        end
        if self.index < 1 then
            self.index = 1
        end
        local sample = self.audio.getSample(self.index)
        if sample then
            local decoded = {
                left = self.leftDecoder(sample.left),
                right = self.rightDecoder(sample.right),
            }
            while self.state ~= "paused" and not self.disposed and not playAudio(self.speakers, decoded) do
                os.pullEvent("speaker_audio_empty")
                sleep(0.5)
            end

            self.index = self.index + 1
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
        artist = self.altMeta.artist or self.audio.artist,
        title = self.altMeta.title or self.audio.title,
        album = self.altMeta.album or self.audio.album,
        size = self.audio.length * 12000,
        length = self.audio.length,
    }
end

function Track:getState()
    return self.state
end

function Track:getPosition()
    return self.index - 1
end

function Track:setPosition(pos)
    if pos < 0 then
        pos = 0
    end
    if pos > self.audio.length then
        pos = self.audio.length
    end
    self.index = pos + 1
    local wasPlaying = self.state ~= "paused"
    self.state = "paused"
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
    self.leftDecoder, self.rightDecoder = createDecoders()
    sleep(0)
    if wasPlaying then
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
    self.index = self.index - 2
    if self.index < 1 then
        self.index = 1
    end
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
    self.leftDecoder, self.rightDecoder = createDecoders()
end

function Track:stop()
    self.state = "paused"
    self.index = 1
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
    self.leftDecoder, self.rightDecoder = createDecoders()
end

function Track:dispose()
    self.disposed = true
    self.handle.close()
end

local function new(handle, name, speakers, decoder, altMeta)
    make_decoder = decoder
    local audio, err = mdfpwm.parse(handle)
    if not audio then
        error(err, 2)
    end

    local track = {
        state = "paused",
        blockSize = 1024 * 16,
        type = driverType,
        speakers = speakers,
        handle = handle,
        audio = audio,
        index = 1,
        disposed = false,
        altMeta = altMeta or {},
    }

    track.leftDecoder, track.rightDecoder = createDecoders()

    setmetatable(track, { __index = Track })
    return track
end

-- returns: isCompatible: bool, weight: number
-- higher weight = higher priority
local function checkCompatibility(handle, name)
    if not handle then
        return false, 10
    end
    local meta, err = mdfpwm.meta(handle)
    return meta ~= nil and name:match("%.mdfpwm$"), 10
end

return {
    new = new,
    type = driverType,
    checkCompatibility = checkCompatibility,
}
