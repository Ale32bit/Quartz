-- SPDX-FileCopyrightText: 2021 The CC: Tweaked Developers
--
-- SPDX-License-Identifier: MPL-2.0
-- https://github.com/cc-tweaked/CC-Tweaked/blob/4daa2a2b6a839769c8be31425780e6c75c1bd752/projects/core/src/main/resources/data/computercraft/lua/rom/modules/main/cc/audio/dfpwm.lua#L163
local expect = require "cc.expect".expect

local byte, floor, band, rshift = string.byte, math.floor, bit32.band, bit32.arshift

local PREC = 10
local PREC_POW = 2 ^ PREC
local PREC_POW_HALF = 2 ^ (PREC - 1)
local STRENGTH_MIN = 2 ^ (PREC - 8 + 1)

local rawMode = false
local function set_raw_mode(enable)
    expect(1, enable, "boolean")
    rawMode = enable
end

local function get_raw_mode()
    return rawMode
end

local function make_predictor()
    local charge, strength, previous_bit = 0, 0, false

    return function(current_bit)
        local target = current_bit and 127 or -128

        local next_charge = charge + floor((strength * (target - charge) + PREC_POW_HALF) / PREC_POW)
        if next_charge == charge and next_charge ~= target then
            next_charge = next_charge + (current_bit and 1 or -1)
        end

        local z = current_bit == previous_bit and PREC_POW - 1 or 0
        local next_strength = strength
        if next_strength ~= z then next_strength = next_strength + (current_bit == previous_bit and 1 or -1) end
        if next_strength < STRENGTH_MIN then next_strength = STRENGTH_MIN end

        charge, strength, previous_bit = next_charge, next_strength, current_bit
        return charge
    end
end
local function make_decoder()
    local predictor = make_predictor()
    local low_pass_charge = 0
    local previous_charge, previous_bit = 0, false

    return function(input)
        expect(1, input, "string")

        local output, output_n = {}, 0
        for i = 1, #input do
            local input_byte = byte(input, i)
            for _ = 1, 8 do
                local current_bit = band(input_byte, 1) ~= 0
                local charge = predictor(current_bit)
                output_n = output_n + 1
                if rawMode then
                    output[output_n] = current_bit and 127 or -128
                else
                    local antijerk = charge
                    if current_bit ~= previous_bit then
                        antijerk = floor((charge + previous_charge + 1) / 2)
                    end

                    previous_charge, previous_bit = charge, current_bit

                    low_pass_charge = low_pass_charge + floor(((antijerk - low_pass_charge) * 140 + 0x80) / 256)

                    output[output_n] = low_pass_charge
                end


                input_byte = rshift(input_byte, 1)
            end
        end

        return output
    end
end

return {
    make_decoder = make_decoder,
    set_raw_mode = set_raw_mode,
    get_raw_mode = get_raw_mode,
}
