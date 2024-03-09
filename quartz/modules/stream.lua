local UI = require("quartz.lib.ui")
local quartz
local ui
local streamUi

local function gui()
    local w, h = quartz.guiWindow.getSize()
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
                local url = read()
                local streamType = url:match("%.(m?dfpwm)$")
                if not streamType then
                    local title = url
                    if #title >= w - 5 then
                        title = title:sub(-(w - 8)) .. "..."
                    end
                    url = "https://cc.alexdevs.me/mdfpwm?url=" ..
                        textutils.urlEncode(url) .. "&title=" .. textutils.urlEncode(title)
                    streamType = "mdfpwm"
                end
                term.setCursorPos(1, 3)
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.black)
                print("Downloading...")
                local hr, err = http.get(url)
                if hr then
                    quartz.loadDriver(hr, "stream." .. streamType)
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

local function init(q)
    quartz = q
    ui = quartz.ui

    quartz.addTask(gui)
end

return init
