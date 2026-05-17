-- src/tool_snap.lua
local Snap = {}

Snap.name = "snap"
Snap.selected = nil
Snap.dragging = false

Snap.text = "" -- This will hold the user input (target ratios string)
Snap.octaveRepeating = false -- Toggle for octave repeating
-- Snap.octaveToggleBounds = nil -- REMOVED

-- Parsed target frequencies in cents (relative to 1/1)
Snap.targetCentIntervals = {}

local CENTS_PER_OCTAVE = 1200
local math_log2 = math.log(2) -- Pre-calculate for efficiency

local function ratio_to_cents(ratio_string)
    local num_str, den_str = ratio_string:match("^(%d+)/(%d+)$")
    if num_str and den_str then
        local num = tonumber(num_str)
        local den = tonumber(den_str)
        if num and den and den ~= 0 then
            return CENTS_PER_OCTAVE * math.log(num / den) / math_log2
        end
    end
    return nil -- Invalid ratio format or division by zero
end

function Snap.init()
    -- Snap.text will be initialized to an empty string.
    -- This variable will be directly updated by main.lua when text input is completed.
end

function Snap.activate()
    -- Called when tool is selected. No special action here yet.
end

function Snap.startEditing()
    -- Directly assign to global variables (assuming main.lua made them global)
    textEntered = Snap.text -- Initialize textEntered with current Snap.text
    textInput = true
    textEditTarget = Snap -- Set Snap as the target for text input
    textInputLabel = "snap pitch to:"
end

-- Snap.draw() REMOVED
-- Snap.mousepressed() REMOVED

-- Dummy mousedown, mousereleased for compliance with currentTool API
function Snap.mousedown()
    -- No specific action for now, but must exist to prevent nil call
end

function Snap.mousereleased()
    -- No specific action for now, but must exist to prevent nil call
end

function Snap.toggleOctaveRepeating()
    Snap.octaveRepeating = not Snap.octaveRepeating
    setMessage("Octave repeating: " .. (Snap.octaveRepeating and "on" or "off"))
end

-- Placeholder for core snapping logic
function Snap.snappingLogic()
    if not Selection.isEmpty() then
        -- 1. Parse Snap.text into Snap.targetCentIntervals
        Snap.targetCentIntervals = {}
        local ratio_strings = {}
        -- Clean up string, remove extra spaces around commas, then split
        local cleaned_text = Snap.text:gsub("%s*,%s*", ",")
        for ratio_str in cleaned_text:gmatch("[^,]+") do -- Split by comma
            table.insert(ratio_strings, ratio_str)
        end

        for _, r_str in ipairs(ratio_strings) do
            local cents = ratio_to_cents(r_str)
            if cents ~= nil then
                table.insert(Snap.targetCentIntervals, cents)
            else
                setMessage("Warning: Invalid ratio '" .. r_str .. "' skipped.")
            end
        end

        if #Snap.targetCentIntervals == 0 then
            setMessage("No valid ratios entered. Snapping aborted.")
            return
        end

        -- 2. Perform snapping for each selected item
        for _, v in ipairs(Selection.list) do
            local current_vy = v.y
                local snapped_vy = current_vy -- Default to current_vy if no suitable snap is found

                local effective_target_vys = {}

                if Snap.octaveRepeating then
                    -- Original logic: generate candidates across octaves based on the current_vy's octave
                    local current_octave_base_vy_for_c = math.floor(current_vy / CENTS_PER_OCTAVE) * CENTS_PER_OCTAVE
                    local oct_offsets_to_check = {0, -CENTS_PER_OCTAVE, CENTS_PER_OCTAVE}

                    for _, oct_offset in ipairs(oct_offsets_to_check) do
                        for _, interval_cents in ipairs(Snap.targetCentIntervals) do
                            table.insert(effective_target_vys, current_octave_base_vy_for_c - interval_cents + oct_offset)
                        end
                    end

                    -- Find the nearest candidate target v.y from all generated candidates
                    local min_diff = math.huge
                    for _, target_vy in ipairs(effective_target_vys) do
                        local diff = math.abs(current_vy - target_vy)
                        if diff < min_diff then
                            min_diff = diff
                            snapped_vy = target_vy
                        end
                    end
                else
                    -- NEW LOGIC: Snapping only to the C4-C5 octave (v.y from 0 to -1200, where 0 is C4)
                    -- First, calculate the equivalent v.y in the reference octave (0 to -1200)
                    local vy_in_ref_octave_equivalent = current_vy % CENTS_PER_OCTAVE
                    if vy_in_ref_octave_equivalent > 0 then
                        vy_in_ref_octave_equivalent = vy_in_ref_octave_equivalent - CENTS_PER_OCTAVE
                    end
                    -- Now vy_in_ref_octave_equivalent is in the range (-CENTS_PER_OCTAVE, 0]

                    -- Generate candidate target v.y's directly within the C4-C5 reference (0 to -1200)
                    local reference_octave_candidates = {}
                    for _, interval_cents in ipairs(Snap.targetCentIntervals) do
                        table.insert(reference_octave_candidates, -interval_cents) -- C4 reference is 0
                    end

                    -- Find the nearest candidate to vy_in_ref_octave_equivalent
                    local min_diff_ref = math.huge
                    local snapped_vy_within_ref_octave = vy_in_ref_octave_equivalent -- Default if no snap

                    for _, target_vy_ref in ipairs(reference_octave_candidates) do
                        local diff = math.abs(vy_in_ref_octave_equivalent - target_vy_ref)
                        if diff < min_diff_ref then
                            min_diff_ref = diff
                            snapped_vy_within_ref_octave = target_vy_ref
                        end
                    end
                    snapped_vy = snapped_vy_within_ref_octave
                end            v.y = snapped_vy
        end
        Undo.register()
        setMessage("Snapping complete. Ratios: " .. Snap.text .. ", Octave repeating: " .. (Snap.octaveRepeating and "on" or "off"))
    else
        setMessage("No items selected for snapping.")
    end
end

return Snap
