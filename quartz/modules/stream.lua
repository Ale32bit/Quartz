local quartz
local ui

local function gui()
    local w, h = quartz.guiWindow.getSize()
    local streamButton = ui:button(w - 7, h, "Stream")
    streamButton.onclick = function(self)
        term.setCursorPos(1, 1)
        write("URL: ")
        local url = read()
        local streamType = url:match("%.(m?dfpwm)$")
        if not streamType then
            url = "https://cc.alexdevs.me/mdfpwm?url=" .. textutils.urlEncode(url)
            streamType = "mdfpwm"
        end
        local h, err = http.get(url)
        if h then
            quartz.loadDriver(h, "stream." .. streamType)
        end
    end
end

local function init(q)
    quartz = q
    ui = quartz.ui

    quartz.addTask(gui)
end

return init