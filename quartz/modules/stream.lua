local UI = require("quartz.lib.ui")
local uriList = require("quartz.lib.urilist")
local memoryStream = require("quartz.lib.memorystream")
local quartz
local ui
local streamUi
local w, h

local function resolveUrl(url)
    local streamType = url:match("%.(m?dfpwm)$")
    if not streamType then
        if url:match("%.urilist$") then
            streamType = "urilist"
        else
            local title = url
            if #title >= w - 5 then
                title = title:sub(-(w - 8)) .. "..."
            end
            url = "https://cc.alexdevs.me/mdfpwm?url=" ..
                textutils.urlEncode(url) .. "&title=" .. textutils.urlEncode(title)
            streamType = "mdfpwm"
        end
    end
    return url, streamType
end

local function streamUrilist(list, meta)
    local uri = table.remove(list, 1)
    repeat
        local streamUrl, streamType = resolveUrl(uri)
        if streamType == "mdfpwm" then
            streamUrl = streamUrl ..
            "&album=" .. textutils.urlEncode(meta.album) .. "&artist=" .. textutils.urlEncode(meta.artist)
        end

        local h, err = http.get(streamUrl, nil, true)
        if h then
            local ms = memoryStream(true)
            ms.write(h.readAll())
            ms.seek("set", 0)
            h.close()
            quartz.loadDriver(ms, "uri." .. streamType)
        end

        os.pullEvent("quartz_driver_end")

        uri = table.remove(list, 1)
    until uri == nil
end

local function autoloop()
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "quartz_driver_end" and quartz.trackSource == "stream" then
            if settings.get("quartz.loop") then
                quartz.play()
            end
        end
    end
end

local function download(url, streamType)
    local hr, err = http.get(url, nil, true)
    if hr then
        if streamType == "urilist" then
            local list, meta = uriList.parse(hr.readAll())
            hr.close()

            quartz.addTask(function()
                streamUrilist(list, meta)
            end)
        else
            local ms = memoryStream(true)
            ms.write(hr.readAll())
            ms.seek("set", 0)

            hr.close()
            quartz.loadDriver(ms, "stream." .. streamType, "stream")
        end
    end
    return hr, err
end

local function gui()
    w, h = quartz.guiWindow.getSize()
    local streamButton = ui:button(w - 7, h, "Stream")
    local win = window.create(quartz.termWindow, 1, 1, w, h, false)
    streamUi = UI(win, quartz.addTask)
    local pid

    local function exit()
        quartz.killTask(pid)
        streamUi.setFocus(false)
        ui.setFocus(true)
    end

    streamUi:label(1, 1, "Insert the URL of the source")

    local exitButton = streamUi:button(w, 1, "x", {
        w = 1,
        buttonBg = colors.black,
        buttonFg = colors.red,
        buttonBgActive = colors.red,
        buttonFgActive = colors.white,
    })
    exitButton.onclick = function(self)
        exit()
    end

    streamButton.onclick = function(self)
        _, pid = quartz.addTask(function()
            ui.setFocus(false)
            streamUi.setFocus(true)
            term.redirect(win)
            term.clear()
            streamUi.redraw()
            while true do
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.black)
                term.setCursorPos(1, 2)
                term.clearLine()
                term.write("URL: ")
                local url, streamType = resolveUrl(read())
                term.setCursorPos(1, 3)
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.black)
                print("Downloading...")
                local hr, err = download(url, streamType)
                if hr then
                    exit()
                else
                    term.setCursorPos(1, 4)
                    term.setTextColor(colors.white)
                    term.setBackgroundColor(colors.black)
                    printError(err)
                end
                
            end
        end)
    end
end

local function onReady()
    os.pullEvent("quartz_ready")

    local trackUrl = quartz.args[1]
    if trackUrl and http.checkURL(trackUrl) then
        local url, streamType = resolveUrl(trackUrl)
        download(url, streamType)
    end
end

local function init(q)
    quartz = q
    ui = quartz.ui

    quartz.addTask(gui)
    quartz.addTask(autoloop)

    quartz.addTask(onReady)
end

return init
