-- PrimeUI by JackMacWindows
-- Public domain/CC0

local expect = require "cc.expect".expect

-- Initialization code
local PrimeUI = {}
do
    local coros = {}
    local restoreCursor

    --- Adds a task to run in the main loop.
    ---@param func function The function to run, usually an `os.pullEvent` loop
    function PrimeUI.addTask(func)
        expect(1, func, "function")
        local t = {coro = coroutine.create(func)}
        coros[#coros+1] = t
        _, t.filter = coroutine.resume(t.coro)
    end

    --- Sends the provided arguments to the run loop, where they will be returned.
    ---@param ... any The parameters to send
    function PrimeUI.resolve(...)
        coroutine.yield(coros, ...)
    end

    --- Clears the screen and resets all components. Do not use any previously
    --- created components after calling this function.
    function PrimeUI.clear()
        -- Reset the screen.
        term.setCursorPos(1, 1)
        term.setCursorBlink(false)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        -- Reset the task list and cursor restore function.
        coros = {}
        restoreCursor = nil
    end

    --- Sets or clears the window that holds where the cursor should be.
    ---@param win window|nil The window to set as the active window
    function PrimeUI.setCursorWindow(win)
        expect(1, win, "table", "nil")
        restoreCursor = win and win.restoreCursor
    end

    --- Gets the absolute position of a coordinate relative to a window.
    ---@param win window The window to check
    ---@param x number The relative X position of the point
    ---@param y number The relative Y position of the point
    ---@return number x The absolute X position of the window
    ---@return number y The absolute Y position of the window
    function PrimeUI.getWindowPos(win, x, y)
        if win == term then return x, y end
        while win ~= term.native() and win ~= term.current() do
            if not win.getPosition then return x, y end
            local wx, wy = win.getPosition()
            x, y = x + wx - 1, y + wy - 1
            _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1) -- gets the parent window through an upvalue
        end
        return x, y
    end

    --- Runs the main loop, returning information on an action.
    ---@return any ... The result of the coroutine that exited
    function PrimeUI.run()
        while true do
            -- Restore the cursor and wait for the next event.
            if restoreCursor then restoreCursor() end
            local ev = table.pack(os.pullEvent())
            -- Run all coroutines.
            for _, v in ipairs(coros) do
                if v.filter == nil or v.filter == ev[1] then
                    -- Resume the coroutine, passing the current event.
                    local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                    -- If the call failed, bail out. Coroutines should never exit.
                    if not res[1] then error(res[2], 2) end
                    -- If the coroutine resolved, return its values.
                    if res[2] == coros then return table.unpack(res, 3, res.n) end
                    -- Set the next event filter.
                    v.filter = res[2]
                end
            end
        end
    end
end

--- Draws a line of text at a position.
---@param win window The window to draw on
---@param x number The X position of the left side of the text
---@param y number The Y position of the text
---@param text string The text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.label(win, x, y, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, text, "string")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    win.setCursorPos(x, y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

--- Creates a progress bar, which can be updated by calling the returned function.
---@param win window The window to draw on
---@param x number The X position of the left side of the bar
---@param y number The Y position of the bar
---@param width number The width of the bar
---@param fgColor color|nil The color of the activated part of the bar (defaults to white)
---@param bgColor color|nil The color of the inactive part of the bar (defaults to black)
---@param useShade boolean|nil Whether to use shaded areas for the inactive part (defaults to false)
---@return function redraw A function to call to update the progress of the bar, taking a number from 0.0 to 1.0
function PrimeUI.progressBar(win, x, y, width, fgColor, bgColor, useShade)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    expect(7, useShade, "boolean", "nil")
    local function redraw(progress)
        expect(1, progress, "number")
        if progress < 0 or progress > 1 then error("bad argument #1 (value out of range)", 2) end
        -- Draw the active part of the bar.
        win.setCursorPos(x, y)
        win.setBackgroundColor(fgColor)
        local integer = math.floor(progress * width)
        win.write((" "):rep(integer))
        local decimal = (progress * width) - integer
        if decimal >= 0.5 then
            win.setBackgroundColor(bgColor)
            win.setTextColor(fgColor)
            win.write("\x95")
        end
        -- Draw the inactive part of the bar, using shade if desired.
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        win.write((useShade and "\x7F" or " "):rep(width - math.floor(progress * width) - (decimal >= 0.5 and 1 or 0)))
    end
    redraw(0)
    return redraw
end

--- Creates a clickable button on screen with text.
---@param win window The window to draw on
---@param x number The X position of the button
---@param y number The Y position of the button
---@param text string The text to draw on the button
---@param action function|string A function to call when clicked, or a string to send with a `run` event
---@param fgColor color|nil The color of the button text (defaults to white)
---@param bgColor color|nil The color of the button (defaults to light gray)
---@param clickedColor color|nil The color of the button when clicked (defaults to gray)
function PrimeUI.button(win, x, y, text, action, fgColor, bgColor, clickedColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, text, "string")
    expect(5, action, "function", "string")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.gray
    clickedColor = expect(8, clickedColor, "number", "nil") or colors.lightGray
    -- Draw the initial button.
    win.setCursorPos(x, y)
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    win.write(" " .. text .. " ")
    -- Get the screen position and add a click handler.
    PrimeUI.addTask(function()
        local buttonDown = false
        while true do
            local event, button, clickX, clickY = os.pullEvent()
            local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
            if event == "mouse_click" and button == 1 and clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                -- Initiate a click action (but don't trigger until mouse up).
                buttonDown = true
                -- Redraw the button with the clicked background color.
                win.setCursorPos(x, y)
                win.setBackgroundColor(clickedColor)
                win.setTextColor(fgColor)
                win.write(" " .. text .. " ")
            elseif event == "mouse_up" and button == 1 and buttonDown then
                -- Finish a click event.
                if clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                    -- Trigger the action.
                    if type(action) == "string" then PrimeUI.resolve("button", action)
                    else action() end
                end
                -- Redraw the original button state.
                win.setCursorPos(x, y)
                win.setBackgroundColor(bgColor)
                win.setTextColor(fgColor)
                win.write(" " .. text .. " ")
            end
        end
    end)
end

--- Draws a line of text, centering it inside a box horizontally.
---@param win window The window to draw on
---@param x number The X position of the left side of the box
---@param y number The Y position of the box
---@param width number The width of the box to draw in
---@param text string The text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.centerLabel(win, x, y, width, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, text, "string")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.black
    assert(#text <= width, "string is too long")
    win.setCursorPos(x + math.floor((width - #text) / 2), y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

return PrimeUI