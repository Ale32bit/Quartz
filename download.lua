local base = "https://raw.github.com/Ale32bit/Quartz/main/"
local files = {
    "player.lua",
    "lib/mdfpwm.lua",
    "lib/drivers/dfpwm.lua",
    "lib/drivers/mdfpwm.lua",
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