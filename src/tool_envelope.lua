local Envelope = {}

Envelope.radius = 30
Envelope.mode = 0 -- 0 for default, 1 for textured
Envelope.modeName = {"default", "airbrush", "glitter"}
Envelope.speckles = {} -- Table to store glitter speckles
Envelope.name = [[
increase envelope
ctrl: decrease
]]

Envelope.preview = false

function Envelope.toggleMode()
    Envelope.mode = (Envelope.mode + 1) % #Envelope.modeName
    setMessage("Envelope brush: " .. Envelope.modeName[Envelope.mode + 1])
end

function Envelope.mousepressed()
	Envelope.table = {}
	Envelope.x = mouseX
	Envelope.y = mouseY
	if Selection.isEmpty() then
		Envelope.table = Edit.editable()
	else
		Envelope.table = Selection.list
	end

    if Envelope.mode == 2 then -- Glitter mode
        Envelope.speckles = {}
        local numSpeckles = math.random(4, 7) -- 4 to 7 speckles per click
        local baseRadius = Envelope.radius * 0.2 -- Speckle radii will be smaller than main brush
        local baseStrength = 0.5 -- Base strength for speckles

        for i = 1, numSpeckles do
            local offsetX = (math.random() * 2 - 1) * Envelope.radius * 0.75 -- Random offset within main brush
            local offsetY = (math.random() * 2 - 1) * Envelope.radius * 0.75
            
            table.insert(Envelope.speckles, {
                x = mouseX + offsetX,
                y = mouseY + offsetY,
                radius = baseRadius * (math.random(50, 100) / 100), -- Randomize speckle size
                strength = baseStrength * (math.random(80, 120) / 100) -- Randomize speckle strength
            })
        end
    end
end

function Envelope.mousedown()
	local radius = Envelope.radius

	for i, v in ipairs(Envelope.table) do
		local x, y = View.transform(v.x, v.y)
		local dist = math.sqrt(0.7 * (x - mouseX) ^ 2 + (y - mouseY) ^ 2)

		local currentWeightRadius = radius


		local weight = math.exp(-(dist / currentWeightRadius) ^ 2) * pres * 0.2

		-- Only process if the vertex is within the effective brush radius
		if weight > 0.001 then
			local processedWeight = weight -- This will be the weight used for actual modification

			if Envelope.mode == 1 then -- Airbrush mode
				processedWeight = processedWeight * 1.75 * (math.random(0, 100) / 100)
				if math.random() > 0.50 then -- More sparse texture
					processedWeight = 0
				end
			elseif Envelope.mode == 2 then -- Glitter mode
                processedWeight = 0
                for _, s in ipairs(Envelope.speckles) do
                    local dx = x - s.x
                    local dy = y - s.y
                    local d = math.sqrt(dx*dx + dy*dy)
                    local speckContribution =
                        math.exp(-(d / s.radius)^2)
                        * s.strength
                        * pres
                        * 0.35 -- User-specified factor
                    processedWeight = processedWeight + speckContribution
                end
            end

            if processedWeight > 0.001 then -- Check if there's any processed weight to apply
                -- Apply the calculated weight
                local wt = math.min(math.max(v.w, 0.01), 0.99)
                wt = math.log(wt / (1 - wt))

                if modifierKeys.ctrl or modifierKeys.cmd then
                    wt = wt - processedWeight
                else
                    wt = wt + processedWeight
                end
                v.w = 1 / (1 + math.exp(-wt))
            end
		end
	end
end

function Envelope.mousereleased() end

return Envelope
