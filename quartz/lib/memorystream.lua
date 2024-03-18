--[[
    MemoryStream (c) 2024 AlexDevs
]]

local expect = require("cc.expect").expect

local function contains(arr, val)
    for i, v in ipairs(arr) do
        if v == val then
            return true
        end
    end
    return false
end

local function new(binaryMode, ...)
    expect(1, binaryMode, "boolean", "nil")
    local position = 0
    local length = 0
    local stream = ""
    local closed = false
    binaryMode = binaryMode == true

    local handle = {}

    function handle._get()
        return stream
    end

    function handle.write(...)
        if closed then
            error("attempt to use a closed handle", 2)
        end
        for i, buffer in ipairs({ ... }) do
            local b
            if type(buffer) == "string" then
                b = buffer
            elseif type(buffer) == "number" then
                b = string.char(buffer)
            else
                error("bad argument #" .. i .. " (string or number expected, got " .. type(buffer) .. ")", 2)
            end

            local buffSize = #b
            local first = stream:sub(1, position)
            local last = stream:sub(position + buffSize + 1, length)
            stream = first .. b .. last
            length = #stream
            position = position + buffSize
        end
    end

    function handle.writeLine(text)
        expect(1, text, "string")
        if closed then
            error("attempt to use a closed handle", 2)
        end

        handle.write(text)
        handle.write("\n")
    end

    function handle.read(count)
        expect(1, count, "number", "nil")
        if closed then
            error("attempt to use a closed handle", 2)
        end
        if count == nil then
            if position >= length then
                return nil
            end
            position = position + 1
            if binaryMode then
                return stream:byte(position, position)
            else
                stream:sub(position, position)
            end
        else
            if count < 0 then
                error("Cannot read a negative number of bytes", 2)
            end

            if position >= length then
                return nil
            end

            position = position + count
            return stream:sub(position - count + 1, position)
        end
    end

    function handle.readAll()
        if closed then
            error("attempt to use a closed handle", 2)
        end
        if position >= length then
            return nil
        end
        local pos = position + 1
        position = length
        return stream:sub(pos, length)
    end

    function handle.readLine(withTrailing)
        expect(1, withTrailing, "nil", "boolean")
        if closed then
            error("attempt to use a closed handle", 2)
        end

        if position >= length then
            return nil
        end

        local chunk, newline = stream:sub(position, length):match("(.-)([\n\r]+)")
        chunk = chunk or stream:sub(position, length)
        newline = newline or ""
        position = position + #chunk + #newline + 1
        if withTrailing then
            return chunk .. newline
        end
        return chunk
    end

    function handle.seek(whence, offset)
        expect(1, whence, "string", "nil")
        expect(2, offset, "number", "nil")
        local options = { "set", "cur", "end" }
        whence = whence or "cur"
        offset = offset or 0

        if not contains(options, whence) then
            error("bad argument #1 to 'seek' (invalid option '" .. whence .. "')", 2)
        end

        if closed then
            error("attempt to use a closed handle", 2)
        end

        if whence == "set" then
            if offset < 0 then
                return nil, "Position is negative"
            end
            position = offset
        elseif whence == "cur" then
            position = position + offset
        elseif whence == "end" then
            position = length + offset
        end

        return position
    end

    function handle.flush()
        if closed then
            error("attempt to use a closed handle", 2)
        end
    end

    function handle.close()
        stream = nil
        closed = true
    end

    handle.write(...)

    return handle
end

return new
