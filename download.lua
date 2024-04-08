local base = "https://raw.githubusercontent.com/Bioscreeper/Quartz/main/"
local files = {
    "player.lua",
    "quartz/lib/ui.lua",
    "quartz/lib/mdfpwm.lua",
    "quartz/lib/rawDfpwm.lua",
    "quartz/lib/urilist.lua",
    "quartz/lib/memorystream.lua",
    "quartz/drivers/dfpwm.lua",
    "quartz/drivers/mdfpwm.lua",
    "quartz/modules/diskDrive.lua",
    "quartz/modules/ui.lua",
    "quartz/modules/stream.lua",
    "quartz/modules/urilist.lua",
}

local function download(url, path)
    print("Downloading", path)
    local h, err = http.get(url)
    if not h then
        printError(err)
        return
    end

    local f = fs.open(path, "w")
    f.write(h.readAll())
    f.close()
    h.close()
    print("Downloaded", path)
end

for i, file in ipairs(files) do
    download(base .. file, file)
end

print("Quartz downloaded!")
