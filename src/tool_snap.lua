-- src/tool_snap.lua
local Snap = {}

Snap.name = "snap"
Snap.selected = nil
Snap.dragging = false

Snap.text = "" -- This will hold the user input (target ratios string)
Snap.octaveRepeating = false -- Toggle for octave repeating

-- Parsed target frequencies in cents (relative to 1/1)
Snap.targetCentIntervals = {}

local CENTS_PER_OCTAVE = 1200
local math_log2 = math.log(2) -- Pre-calculate for efficiency

local function trim(s)
    if type(s) ~= "string" then return s end
    return s:match("^%s*(.-)%s*$") or ""
end

-- Helper to parse N/M ratio string into its numerator and denominator
local function parse_single_ratio_as_num_den(ratio_string)
    local num_str, den_str = ratio_string:match("^(%d+)/(%d+)$")
    if not den_str then -- Check if it's an integer like "2"
        num_str = ratio_string:match("^(%d+)$")
        if num_str then den_str = "1" end
    end
    if num_str and den_str then
        local num = tonumber(num_str)
        local den = tonumber(den_str)
        if num and den and den ~= 0 then
            return num, den
        end
    end
    return nil, nil
end

-- Helper to parse N/M ratio string into cent value
local function parse_ratio_to_cents(ratio_string)
    local num, den = parse_single_ratio_as_num_den(ratio_string)
    if num and den then
        return CENTS_PER_OCTAVE * math.log(num / den) / math_log2
    end
    return nil -- Invalid ratio format or division by zero
end

-- Helper to parse N:M:P or N::M enumerated ratios into cent values
local function parse_enumerated_ratios(enum_string)
    local cents_list = {}
    
    -- Check for N::M format
    local first_num_str, last_num_str = enum_string:match("^(%d+)::(%d+)$")
    if first_num_str and last_num_str then
        local first_num = tonumber(first_num_str)
        local last_num = tonumber(last_num_str)
        if first_num and last_num and first_num > 0 and first_num <= last_num then
            for i = first_num, last_num do
                table.insert(cents_list, CENTS_PER_OCTAVE * math.log(i / first_num) / math_log2)
            end
            return cents_list
        end
    end

    -- Check for N:M:P format
    local parts_str = {}
    for part in enum_string:gmatch("([^:]+)") do
        table.insert(parts_str, part)
    end

    if #parts_str >= 2 then -- At least "base:ratio"
        local base_denom = tonumber(parts_str[1])
        if base_denom and base_denom ~= 0 then
            for i = 1, #parts_str do
                local current_num = tonumber(parts_str[i])
                if current_num then
                    table.insert(cents_list, CENTS_PER_OCTAVE * math.log(current_num / base_denom) / math_log2)
                end
            end
            return cents_list
        end
    end
    
    return nil -- Invalid enumerated ratio format
end

-- Helper to parse "n"edo format into a list of all cent steps
local function parse_full_edo(edo_string)
    local n_str = edo_string:match("^(%d+)edo$")
    if n_str then
        local n = tonumber(n_str)
        if n and n > 0 then
            local cents_per_step = CENTS_PER_OCTAVE / n
            local cents_list = {}
            for i = 0, n - 1 do
                table.insert(cents_list, i * cents_per_step)
            end
            return cents_list
        end
    end
    return nil -- Invalid EDO format
end

-- Helper to parse "n\EDO#" format into a single cent step
local function parse_edo_step(step_string)
    local s_str, e_str = step_string:match([[^(%d+)\\(%d+)$]])
    if s_str and e_str then
        local s = tonumber(s_str)
        local e = tonumber(e_str)
        if s and e and e > 0 then
            return { s * (CENTS_PER_OCTAVE / e) }
        end
    end
    return nil -- Invalid EDO step format
end

-- Forward declarations for mutually recursive local functions
local parse_pitch_spec
local parse_multiplied_expression

-- Helper to parse multiplied expressions like "A(B)"
parse_multiplied_expression = function(expr_string)
    -- Pattern: Multiplier(Multiplicand). Multiplier can be N/D or N. Multiplicand can be anything.
    local multiplier_part, multiplicand_part = expr_string:match("^(%S+)%((.*)%)$") -- %S+ matches non-whitespace characters for multiplier
                                                                                 -- (.*) captures everything inside parentheses

    if multiplier_part and multiplicand_part then
        local multiplier_cents_offset = parse_ratio_to_cents(multiplier_part)
        if not multiplier_cents_offset then return nil end -- Invalid multiplier format

        local combined_cents_list = {}
        -- Multiplicand part can be a comma-separated list of pitch specifications
        local multiplicand_specs = {}
        local cleaned_multiplicand = multiplicand_part:gsub("%s*,%s*", ",")
        for spec_item in cleaned_multiplicand:gmatch("[^,]+") do
            table.insert(multiplicand_specs, spec_item)
        end

        for _, spec in ipairs(multiplicand_specs) do
            -- Recursively parse each part of the multiplicand
            local parsed_multiplicand_cents = parse_pitch_spec(spec)
            if parsed_multiplicand_cents then
                for _, cents_val in ipairs(parsed_multiplicand_cents) do
                    table.insert(combined_cents_list, cents_val + multiplier_cents_offset)
                end
            end
        end
        return combined_cents_list
    end
    return nil
end

-- Main dispatcher to parse any pitch specification string
parse_pitch_spec = function(spec_string)
    spec_string = trim(spec_string) -- Remove whitespace

    -- Try Multiplied Expression first
    local result = parse_multiplied_expression(spec_string)
    if result then return result end

    -- Try EDO step next (most specific regex with '')
    result = parse_edo_step(spec_string)
    if result then return result end

    -- Try Full EDO
    result = parse_full_edo(spec_string)
    if result then return result end

    -- Try Enumerated Ratios (check for ':' or '::')
    if spec_string:find(":") then -- Contains at least one colon
        result = parse_enumerated_ratios(spec_string)
        if result then return result end
    end
    
    -- Try standard Ratio (N/M) last
    local single_cent_result = parse_ratio_to_cents(spec_string) -- Pass string directly
    if single_cent_result ~= nil then return {single_cent_result} end -- Wrap single result in a list

    return nil -- No matching format
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
        local ratio_spec_strings = {}
        -- Clean up string, remove extra spaces around commas, then split
        local cleaned_text = Snap.text:gsub("%s*,%s*", ",")
        for spec_str in cleaned_text:gmatch("[^,]+") do -- Split by comma
            table.insert(ratio_spec_strings, spec_str)
        end

        local all_parsed_cents = {}
        for _, spec_str in ipairs(ratio_spec_strings) do
            local cents_list = parse_pitch_spec(spec_str)
            if cents_list then
                for _, cents_val in ipairs(cents_list) do
                    table.insert(all_parsed_cents, cents_val)
                end
            else
                setMessage("Warning: Invalid pitch specification '" .. spec_str .. "' skipped.")
            end
        end

        if #all_parsed_cents == 0 then
            setMessage("No valid pitch specifications entered. Snapping aborted.")
            return
        end
        Snap.targetCentIntervals = all_parsed_cents -- Update the target intervals

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
                -- When octaveRepeating is OFF, the target intervals are absolute offsets from C4 (v.y = 0).
                -- The selected item's v.y should snap to the nearest of these absolute targets.

                -- The effective_target_vys list is simply the inversion of Snap.targetCentIntervals,
                -- as lower v.y is higher pitch, and C4 is v.y = 0.
                effective_target_vys = {}
                for _, interval_cents in ipairs(Snap.targetCentIntervals) do
                    table.insert(effective_target_vys, -interval_cents)
                end

                -- Now, find the nearest candidate to the current_vy from this list of absolute targets.
                local min_diff = math.huge
                for _, target_vy in ipairs(effective_target_vys) do
                    local diff = math.abs(current_vy - target_vy)
                    if diff < min_diff then
                        min_diff = diff
                        snapped_vy = target_vy
                    end
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
