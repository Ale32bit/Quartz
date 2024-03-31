local UI = {}

local function new(self, win, addTask)
    local ui = {
        window = win,
        addTask = addTask,
        active = true,
        elements = {},
        defaultColors = {
            text = colors.white,
            background = colors.black,
            progressFg = colors.white,
            progressBg = colors.gray,
            buttonFg = colors.white,
            buttonBg = colors.lightGray,
            buttonFgActive = colors.black,
            buttonBgActive = colors.white,
        }
    }

    function ui.redraw()
        ui.window.setBackgroundColor(ui.defaultColors.background)
        ui.window.setTextColor(ui.defaultColors.text)
        ui.window.clear()
        for i, element in pairs(ui.elements) do
            element.redraw()
        end
    end

    function ui.setFocus(enable)
        ui.active = enable
        ui.window.setVisible(enable)
        if enable then
            ui.redraw()
        end
    end

    ui.redraw()

    return setmetatable(ui, { __index = UI })
end

function UI:label(x, y, text, options)
    options = options or {}
    local element = {
        x = x,
        y = y,
        text = text,

        colors = {
            text = options.text or self.defaultColors.text,
            background = options.background or self.defaultColors.background,
            activeText = options.activeText or self.defaultColors.activeText,
            activeBackground = options.activeBackground or self.defaultColors.activeBackground,
        }
    }

    function element.redraw()
        self.window.setCursorPos(element.x, element.y)
        self.window.setBackgroundColor(element.colors.background)
        self.window.setTextColor(element.colors.text)
        self.window.write(element.text)
    end

    function element.setText(text)
        element.text = string.rep(" ", #element.text)
        element.redraw()
        element.text = text
        element.redraw()
    end

    table.insert(self.elements, element)

    element.redraw()

    return element
end

function UI:centerLabel(x, y, w, text, options)
    options = options or {}
    local element = {
        x = x,
        y = y,
        text = text,
        w = w,

        colors = {
            text = options.text or self.defaultColors.text,
            background = options.background or self.defaultColors.background,
            activeText = options.activeText or self.defaultColors.activeText,
            activeBackground = options.activeBackground or self.defaultColors.activeBackground,
        }
    }

    function element.redraw()
        local centerx = math.floor((w - #element.text) / 2)
        self.window.setCursorPos(element.x + centerx, element.y)
        self.window.setBackgroundColor(element.colors.background)
        self.window.setTextColor(element.colors.text)
        self.window.write(element.text)
    end

    function element.setText(text)
        element.text = string.rep(" ", #element.text)
        element.redraw()
        element.text = text
        element.redraw()
    end

    table.insert(self.elements, element)

    element.redraw()

    return element
end

function UI:button(x, y, text, options)
    options = options or {}
    local element = {
        x = x,
        y = y,
        text = text,

        w = options.w or #text + 2,
        h = options.h or 1,
        hasW = options.w ~= nil,

        active = false,
        border = options.border == true, -- defaults to false, not nil

        colors = {
            buttonFg = options.buttonFg or self.defaultColors.buttonFg,
            buttonBg = options.buttonBg or self.defaultColors.buttonBg,
            buttonFgActive = options.buttonFgActive or self.defaultColors.buttonFgActive,
            buttonBgActive = options.buttonBgActive or self.defaultColors.buttonBgActive,
        }
    }

    local function filledBox(x, y, w, h, color, win)
        for i = 0, h - 1 do
            win.setCursorPos(x, y + i)
            win.setBackgroundColor(color)
            local blitColor = colors.toBlit(color)
            win.blit((" "):rep(w), (blitColor):rep(w), (blitColor):rep(w))
        end
    end

    function element.redraw()
        local bg = element.active and element.colors.buttonBgActive or element.colors.buttonBg
        local fg = element.active and element.colors.buttonFgActive or element.colors.buttonFg
        filledBox(element.x, element.y, element.w, element.h, bg, self.window)

        local centerx, centery = x + math.floor((element.w - #element.text) / 2), y + math.floor(element.h / 2)
        self.window.setCursorPos(centerx, centery)
        self.window.setTextColor(fg)
        self.window.write(element.text)
    end

    function element.onclick(self)

    end

    self.addTask(function()
        while true do
            local ev, b, x, y = os.pullEvent()
            if self.active then
                if ev == "mouse_click" then
                    if x >= element.x and y >= element.y
                        and x < element.x + element.w and y < element.y + element.h then
                        element.active = true
                        element.redraw()
                    end
                elseif ev == "mouse_up" then
                    element.active = false
                    element.redraw()

                    if x >= element.x and y >= element.y
                        and x < element.x + element.w and y < element.y + element.h then
                        element:onclick()
                    end
                end
            end
        end
    end)

    table.insert(self.elements, element)

    element.redraw()

    return element
end

function UI:progress(x, y, w, level, options)
    options = options or {}
    local element = {
        x = x,
        y = y,
        w = w,
        level = level or 0,

        colors = {
            progressFg = options.progressFg or self.defaultColors.progressFg,
            progressBg = options.progressBg or self.defaultColors.progressBg,
        }
    }

    function element.redraw()
        self.window.setCursorPos(x, y)
        self.window.setBackgroundColor(element.colors.progressFg)
        local integer = math.floor(element.level * element.w)
        self.window.write((" "):rep(integer))
        local decimal = (element.level * element.w) - integer
        if decimal >= 0.5 then
            self.window.setBackgroundColor(element.colors.progressBg)
            self.window.setTextColor(element.colors.progressFg)
            self.window.write("\x95")
        end
        self.window.setBackgroundColor(element.colors.progressBg)
        self.window.setTextColor(element.colors.progressFg)
        self.window.write(string.rep(" ", element.w - math.floor(element.level * element.w) - (decimal >= 0.5 and 1 or 0)))
    end

    function element.setLevel(level)
        element.level = level
        element.redraw()
    end

    function element.onclick(self, level)

    end

    element.redraw()

    self.addTask(function()
        while true do
            local ev, b, x, y = os.pullEvent("mouse_click")
            if self.active then
                if x >= element.x and y == element.y and x < element.x + element.w then
                    local p = (x - element.x) / (element.w - 1)
                    element:onclick(p)
                end
            end
        end
    end)

    table.insert(self.elements, element)

    return element
end

setmetatable(UI, {
    __call = new,
})

return UI
