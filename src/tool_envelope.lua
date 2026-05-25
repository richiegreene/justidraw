local Envelope = {}

Envelope.radius = 30
Envelope.mode = 0 -- 0 for default, 1 for textured
Envelope.modeName = {"default", "airbrush"}
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
		Envelope.table = song.track[1]
	else
		Envelope.table = Selection.list
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
				processedWeight = processedWeight * 1.2 * (math.random(0, 100) / 100) -- Slightly increased pressure
				if math.random() > 0.85 then -- More sparse texture
					processedWeight = 0
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
