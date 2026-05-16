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

            local candidate_target_vys = {}

            -- Determine the current octave block for the selected v.y
            local current_octave_base_vy_for_c = math.floor(current_vy / CENTS_PER_OCTAVE) * CENTS_PER_OCTAVE

            -- Generate target v.y values in the vicinity of the current v.y
            local oct_offsets_to_check = {0}
            if Snap.octaveRepeating then
                table.insert(oct_offsets_to_check, -CENTS_PER_OCTAVE)
                table.insert(oct_offsets_to_check, CENTS_PER_OCTAVE)
            end

            for _, oct_offset in ipairs(oct_offsets_to_check) do
                for _, interval_cents in ipairs(Snap.targetCentIntervals) do
                    table.insert(candidate_target_vys, current_octave_base_vy_for_c - interval_cents + oct_offset)
                end
            end

            -- Find the nearest candidate target v.y
            local min_diff = math.huge
            local snapped_vy = current_vy

            for _, target_vy in ipairs(candidate_target_vys) do
                local diff = math.abs(current_vy - target_vy)
                if diff < min_diff then
                    min_diff = diff
                    snapped_vy = target_vy
                end
            end
            v.y = snapped_vy
        end
        Undo.register()
        setMessage("Snapping complete. Ratios: " .. Snap.text .. ", Octave repeating: " .. (Snap.octaveRepeating and "on" or "off"))
    else
        setMessage("No items selected for snapping.")
    end
end

return Snap
