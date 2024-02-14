--[[
    Weird MDFPWM encoder

    Format:
    leftSize = 4 bytes LE length of left channel
    rightSide = 4 bytes LE length of right channel
    LEFT CHANNEL BLOCK * leftSize
    RIGHT CHANNEL BLOCK * rightSize

    there are some bugs
]]

local url, title, artist, album = ...

print("WARNING: This tool is deprecated")

if not url then
    error("Usage: url, title, artist, album", 0)
end

local function prompt(question)
    write(question)
    return read()
end

title = title or prompt("Track title: ")
artist = artist or prompt("Track artist: ")
album = album or prompt("Track album: ")

local h, err = http.get(url, nil, true)
if not h then
    error(err, 0)
end

local fullSize = h.seek("end")
h.seek("set", 0)

print(fullSize, "bytes")

local leftSize, rightSize, leftOffset = string.unpack("<II", h.read(8))
local blocks = math.ceil(leftSize / 6000)
leftOffset = leftOffset - 1

print("Block sizes:")
print(string.format("%d < - > %d", leftSize, rightSize))

print(string.format("This track is expected to be %.2f seconds long", blocks))

local f = fs.open("disk/audio.mdfpwm", "wb")

f.write("MDFPWM\003")
f.write(string.pack("<Is1s1s1", leftSize + rightSize, artist, title, album))

local rightOffset = leftOffset + leftSize
local blockSize = 6000

print(leftOffset, rightOffset, rightSize)

h.seek("set", leftOffset)

local function getLeftChunk(i)
    h.seek("set", leftOffset + (i * blockSize))
    return h.read(blockSize)
end

local function getRightChunk(i)
    h.seek("set", rightOffset + (i * blockSize))
    return h.read(blockSize)
end

for i = 0, blocks - 1 do
    f.write(getLeftChunk(i))
    f.write(getRightChunk(i))

    if i % 4096 == 0 then
        print(string.format("%.2f - %d / %d", i / blocks, i, blocks))
    end

    if i % 16384 == 0 then
        sleep(0)
    end
end

h.close()
f.close()

print("Track created in /disk/audio.mdfpwm")