-- MDFPWM parser library by AlexDevs

-- This library reads Drucifer's MDFPWMv3 files
-- Consider donating to Drucifer@SwitchCraft.kst for the format

local sub = string.sub
local function verifyHeader(handle)
    return handle.read(7) == "MDFPWM\003"
end

local function readMetadata(handle)
    return string.unpack("<Is1s1s1", handle.read(770))
end

local function parse(handle)
    if not handle or type(handle) ~= "table" or not handle.read then
        return false, "Incorrect handle provided"
    end

    if not verifyHeader(handle) then
        return false, "MDFPWMv3 header not found"
    end

    local currentPos = handle.seek()
    local dataLength, artist, title, album, headerLength = readMetadata(handle)
    local sampleCount = math.ceil(dataLength / 12000)
    handle.seek("set", currentPos + headerLength + 1)

    local dataStream = handle.read(dataLength)

    local function getSample(index)
        if index < 1 or index > sampleCount then
            return nil
        end

        local sampleData = sub(dataStream, ((index - 1) * 12000) + 1, index * 12000)
        return {
            left = sub(sampleData, 1, 6000),
            right = sub(sampleData, 6001, 12000),
        }
    end

    return {
        artist = artist,
        title = title,
        album = album,
        length = sampleCount,
        getSample = getSample,
    }
end

local function meta(handle)
    local currentPos = handle.seek()
    if verifyHeader(handle) then
        local data = {}
        data.len, data.artist, data.title, data.album = readMetadata(handle)
        data.len = math.ceil(data.len / 12000)
        data.length = data.len
        handle.seek("set", currentPos)
        return data
    end

    handle.seek("set", currentPos)
    return false, "Not MDFPWMv3 Formatted"
end

return {
    parse = parse,
    meta = meta,
    read = parse,
}
