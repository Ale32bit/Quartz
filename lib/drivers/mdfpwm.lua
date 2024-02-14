local dfpwm = require("cc.audio.dfpwm")
local mdfpwm = require("lib.mdfpwm")

local driverType = "mdfpwm"

local Track = {}

local function getAverage(left, right)
    local avg = {}
    for i = 1, #left do
        avg[i] = (left[i] + right[i]) / 2
    end
    return avg
end

local function playAudio(speakers, sample)
    if speakers.isMono then
        return speakers.left.playAudio(getAverage(sample.left, sample.right))
    end

    if #sample.left ~= #sample.right then
        printError("channel size difference!")
        print(#sample.left, #sample.right)
    end

    local ok = true
    if #sample.left > 0 then
        ok = ok and speakers.left.playAudio(sample.left)
    end
    if #sample.right > 0 then
        ok = ok and speakers.right.playAudio(sample.right)
    end

    return ok
end

local function stopAudio(speakers)
    speakers.left.stop()
    if speakers.isMono then
        return
    end
    speakers.right.stop()
end

local function createDecoders()
    return dfpwm.make_decoder(), dfpwm.make_decoder()
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
        if not sample then
            break
        end
        local decoded = {
            left = self.leftDecoder(sample.left),
            right = self.rightDecoder(sample.right),
        }
        while self.state ~= "paused" and not self.disposed and not playAudio(self.speakers, decoded) do
            os.pullEvent("speaker_audio_empty")
            sleep(0.5)
        end
        self.index = self.index + 1
    end
    os.queueEvent("quartz_driver_end")
end

function Track:getMeta()
    return {
        artist = self.audio.artist,
        title = self.audio.title,
        album = self.audio.album,
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
    self.index = pos + 1
    self:pause()
    self.leftDecoder, self.rightDecoder = createDecoders()
    self:play()
end

function Track:play()
    self.state = "running"
    os.queueEvent("speaker_audio_empty")
    os.queueEvent("quartz_play")
end

function Track:pause()
    self.state = "paused"
    os.queueEvent("quartz_pause")
    self.index = self.index - 2
    stopAudio(self.speakers)
end

function Track:stop()
    self.state = "paused"
    self.index = 0
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
    self.leftDecoder, self.rightDecoder = createDecoders()
end

function Track:dispose()
    self.disposed = true
    self.handle.close()
end

local function new(drive, speakers)
    local drivePath = drive.getMountPath()
    local found = fs.find(fs.combine(drivePath, "*.mdfpwm"))
    local filePath = found[1]
    if not filePath then
        error("No compatible files!")
    end

    local handle = fs.open(filePath, "rb")
    local audio = mdfpwm.parse(handle)

    local track = {
        state = "paused",
        blockSize = 1024 * 16,
        type = driverType,
        speakers = speakers,
        handle = handle,
        audio = audio,
        index = 1,
        disposed = false,
    }

    track.leftDecoder, track.rightDecoder = createDecoders()

    setmetatable(track, { __index = Track })
    return track
end

-- returns: isCompatible: bool, weight: number
-- higher weight = higher priority
local function checkCompatibility(drive)
    if not drive.hasData() then
        return false
    end

    local path = drive.getMountPath()
    local found = fs.find(fs.combine(path, "*.mdfpwm"))
    return #found > 0, 10
end

return {
    new = new,
    type = driverType,
    checkCompatibility = checkCompatibility,
}