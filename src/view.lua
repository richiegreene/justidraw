--[[
camera and drawing
]]

local harmonicColorTable = require("harmonics")
local View = {}

View.x = 0
View.y = 0
View.zoomX = 0.3
View.zoomY = 0.3

local function log2(x)
	return math.log(x) / math.log(2)
end

local function drawHarmonics(ix, iy, ex, ey, sx, sy)
	local notes = {}
	local j = 1

	for i, v in ipairs(song.track[1]) do
		local x, _ = View.invTransform(mouseX, mouseY)
		if v.r and v.x <= x and v.r.x > x then
			local a = (x - v.x) / (v.r.x - v.x)

			local yy = (1 - a) * v.y + a * v.r.y
			notes[j] = yy

			j = j + 1
		end
	end

	if notes[1] then
		for i, v in ipairs(notes) do
			notes[i] = 2 ^ (-notes[i] / 1200)
		end
		table.sort(notes)
		local f1 = notes[1]
		local bestFit = 1
		local lowestError = math.huge
		for i = 1, 16 do
			local err = 0
			for k, v in ipairs(notes) do
				local f = i * v / f1

				err = err + (math.floor(f + 0.5) - f) ^ 2
			end
			--arbitrary weights
			err = err * i

			if err < lowestError then
				bestFit = i
				lowestError = err
			end
		end

		f1 = f1 / bestFit

		for i, col in pairs(harmonicColorTable) do
			local f = i * f1
			local y = -log2(f) * 1200

			love.graphics.setColor(col)
			love.graphics.print(i, sx * ix + 2, sy * y - 13)
			--love.graphics.setColor(1,0,0,0.5)
			love.graphics.line(sx * ix, sy * y, sx * ex, sy * y)
		end
	end
end

--[[
the barlines engrave read off this drawing, drawn instead of the fixed grid.

the hierarchy is the same one the plain grid has, so that switching between them
does not feel like switching applications: a bold line where the bar is, a
medium one on the beat, a faint one under a subdivision. what has changed is that
the lines are where the music turns rather than every hundred units.

an anchor the composer tagged by hand is drawn in the theme's highlight colour
and a little heavier. that distinction is the whole reason the roles are sent
across at all -- a beat engrave worked out by interpolating and a beat somebody
put there on purpose are different claims, and the second one is the one you
would want to check against the drawing.
]]
local function drawTempoMap(ix, iy, ex, ey, sx, sy)
	local grid = Theme.current.grid
	local hi = Theme.current.highlight
	local text = Theme.current.text

	local y0 = sy * iy
	local y1 = sy * ey

	-- the beats and subdivisions first, so a barline is never drawn under one.
	--
	-- a tagged anchor is a claim the composer made on purpose and is kept
	-- however far out the view goes. an untagged one is the engraver's own
	-- reading, and readings finer than the beat are only useful once you are
	-- close enough to need them: at a distance they are just noise between the
	-- beats and bars, the same way a ruler marked in millimetres reads as
	-- solid black from across the room.
	--
	-- what "too close together" means depends on the piece -- a fast passage
	-- packs more beats per pixel than a slow one at the same zoom -- so this
	-- is decided on screen distance, not on a fixed zoom level: each tier
	-- keeps its own last-drawn position and skips a line that would land
	-- closer to it than MIN_GAP pixels. subdivisions drop out first, using
	-- the widest gap, then beats, leaving bars (below) to carry the shape of
	-- the piece when zoomed far out.
	local MIN_GAP = 6
	local lastFineSX = -math.huge
	local lastBeatSX = -math.huge
	for _, a in ipairs(TempoMap.anchors) do
		if a.x >= ix - 100 and a.x <= ex + 100 and a.role ~= "downbeat" then
			local ax = sx * a.x
			local c = a.tagged and hi or grid
			local alpha = 0.25
			local tierGap = MIN_GAP * 3 -- subdivision / exclude / other fine-grained roles
			local lastSX = lastFineSX
			if a.role == "beat" then
				alpha = 0.5
				tierGap = MIN_GAP
				lastSX = lastBeatSX
			elseif a.role == "hold" then
				alpha = 0.6
				tierGap = MIN_GAP
				lastSX = lastBeatSX
			elseif a.role == "exclude" then
				alpha = 0.12
			end
			if a.tagged then
				alpha = math.min(1, alpha + 0.25)
				tierGap = 0
			end
			if ax - lastSX >= tierGap then
				love.graphics.setColor(c[1], c[2], c[3], alpha)
				love.graphics.line(ax, y0, ax, y1)
				if a.role == "beat" or a.role == "hold" then
					lastBeatSX = ax
				else
					lastFineSX = ax
				end
			end
		end
	end

	-- then the bars, over the top, with their numbers. thinned the same way,
	-- so a piece with many short bars does not leave the grid looking just as
	-- dense as it was before the beats and subdivisions dropped out
	local lastBarSX = -math.huge
	for _, b in ipairs(TempoMap.bars) do
		if b.x >= ix - 100 and b.x <= ex + 100 then
			local bx = sx * b.x
			if bx - lastBarSX >= MIN_GAP * 2 then
				lastBarSX = bx
				love.graphics.setColor(grid[1], grid[2], grid[3], 0.85)
				love.graphics.line(bx, y0, bx, y1)

				-- the bar number, held at the top of the view rather than at the top
				-- of the piece, so it is readable wherever the composer has scrolled
				love.graphics.setColor(text[1], text[2], text[3], 0.75)
				love.graphics.print(b.number, bx + 3, y0 + 3)
			end
		end
	end
end

function View.draw()
	love.graphics.push()
	love.graphics.translate(View.x, View.y)
	local sx, sy = View.zoomX, View.zoomY

	local ix, iy = View.invTransform(0, 0)
	local ex, ey = View.invTransform(width, height)

	local grid_r = Theme.current.grid[1]
	local grid_g = Theme.current.grid[2]
	local grid_b = Theme.current.grid[3]

	local bg_r = Theme.current.background[1]
	local bg_g = Theme.current.background[2]
	local bg_b = Theme.current.background[3]

	local showHarmonics = love.keyboard.isDown("y") and not textInput

	if showHarmonics then
		drawHarmonics(ix, iy, ex, ey, sx, sy)
	else
		if Theme.current.showGridPitch then
			local isBlackKey = { [1] = true, [3] = true, [6] = true, [8] = true, [10] = true }
			local bgLum = 0.3 * bg_r + 0.6 * bg_g + 0.1 * bg_b
			local lineAlpha = math.min(1.0, math.max(0.4, sy * 1.5))

			-- 1. Draw horizontal piano roll background bands for black key pitches (C#, D#, F#, G#, A#)
			for i = math.floor(iy / 100) - 1, math.floor(ey / 100) + 1 do
				local k = ((9 - i) % 12 + 12) % 12
				if isBlackKey[k] then
					if bgLum < 0.5 then
						-- Dark theme: inverted / brighter chromatic bands
						love.graphics.setColor(1.0, 1.0, 1.0, 0.12)
					else
						-- Light theme: darker chromatic bands
						love.graphics.setColor(0.0, 0.0, 0.0, 0.10)
					end
					love.graphics.rectangle("fill", sx * ix, sy * (i - 0.5) * 100, sx * (ex - ix), sy * 100)
				end
			end

			-- 2. Draw 12EDO pitch grid lines (bold lines on C octaves)
			for i = math.floor(iy / 100) + 1, math.floor(ey / 100) do
				local k = ((9 - i) % 12 + 12) % 12
				if k == 0 then
					-- C octave divider line (prominent)
					love.graphics.setColor(grid_r, grid_g, grid_b, 0.75 * lineAlpha)
				elseif k == 5 then
					-- F divider line (mid-octave)
					love.graphics.setColor(grid_r, grid_g, grid_b, 0.35 * lineAlpha)
				else
					-- Standard chromatic semitone line
					love.graphics.setColor(grid_r, grid_g, grid_b, 0.18 * lineAlpha)
				end
				love.graphics.line(sx * ix, sy * i * 100, sx * ex, sy * i * 100)
			end
		end
	end

	if Theme.current.showGridTime then
		if TempoMap and TempoMap.active and TempoMap.show then
			drawTempoMap(ix, iy, ex, ey, sx, sy)
		else
			-- draw bpm grid
			for i = math.floor(ix / 100) + 1, math.floor(ex / 100) do
				love.graphics.setColor(grid_r, grid_g, grid_b, 0.25 * sx)
				if (i - song.bpmOffset) % 4 == 0 then
					love.graphics.setColor(grid_r, grid_g, grid_b, 1 * sx)
				end
				if (i - song.bpmOffset) % 16 == 0 then
					love.graphics.setColor(grid_r, grid_g, grid_b, 4 * sx)
				end
				love.graphics.line(sx * i * 100, sy * iy, sx * i * 100, sy * ey)
			end
		end
	end

	-- variable width lines showing pressure
	local lw = Theme.current.lineWidth
	-- love.graphics.setColor(Theme.current.envelope)
	local envelope = Theme.current.envelope
	local parts = Theme.current.parts



	local muted = Edit.mutedParts
	local muteFade = Theme.current.muteFade

	-- muted parts are greyed out, that is, faded towards the background
	local function setColor(c, isMuted)
		if isMuted then
			love.graphics.setColor(
				c[1] + (bg_r - c[1]) * muteFade,
				c[2] + (bg_g - c[2]) * muteFade,
				c[3] + (bg_b - c[3]) * muteFade
			)
		else
			love.graphics.setColor(c)
		end
	end

	for i, v in ipairs(song.track[1]) do
		if v.r then
			-- notes assigned to a part are drawn in that part's color
			local c = envelope
			if v.part and parts[v.part] then
				c = parts[v.part].color
			end
			local b = (v.w + v.r.w) * 0.4 + 0.2
			-- fading the pressure blend is the same as fading the color itself
			if muted[v.part or 0] then
				b = b * (1 - muteFade)
			end
			love.graphics.setColor(c[1] * b + bg_r * (1 - b), c[2] * b + bg_g * (1 - b), c[3] * b + bg_b * (1 - b))
			local w1 = v.w * lw
			local w2 = v.r.w * lw
			love.graphics.polygon(
				"fill",
				sx * v.x,
				sy * (v.y + w1 + 1),
				sx * v.r.x,
				sy * (v.r.y + w2 + 1),
				sx * v.r.x,
				sy * (v.r.y - w2 - 1),
				sx * v.x,
				sy * (v.y - w1 - 1)
			)
			love.graphics.line(sx * v.x, sy * (v.y + w1 + 1), sx * v.r.x, sy * (v.r.y + w2 + 1))
			love.graphics.line(sx * v.x, sy * (v.y - w1 - 1), sx * v.r.x, sy * (v.r.y - w2 - 1))
		end
	end

	local ptSize = math.min(4 * math.sqrt(sx ^ 2 + sy ^ 2), 3)
	local ptSizeSel = math.max(ptSize * 1.2, 2)

	for i, v in ipairs(song.track[1]) do
		-- a part brings its own pair of colors along
		local p = v.part and parts[v.part]
		local highlightColor = p and p.highlight or Theme.current.highlight
		local vertexColor = p and p.color or Theme.current.vertices
		local isMuted = muted[v.part or 0]

		if v.r then
			if Selection.mask[v] and Selection.mask[v.r] then
				setColor(highlightColor, isMuted)
				love.graphics.line(sx * v.x, sy * v.y, sx * v.r.x, sy * v.r.y)
			elseif Theme.current.showVertices then
				setColor(vertexColor, isMuted)
				love.graphics.line(sx * v.x, sy * v.y, sx * v.r.x, sy * v.r.y)
			end
		end
		if Selection.mask[v] then
			setColor(highlightColor, isMuted)
			love.graphics.ellipse("fill", sx * v.x, sy * v.y, ptSizeSel, ptSizeSel)
		elseif Theme.current.showVertices then
			setColor(vertexColor, isMuted)
			love.graphics.ellipse("fill", sx * v.x, sy * v.y, ptSizeSel, ptSizeSel)
		end
	end

	love.graphics.setColor(Theme.current.playhead)
	local at = Audio.timeSmooth
	love.graphics.line(sx * at, sy * iy, sx * at, sy * ey)

	love.graphics.pop()
end

function View.invTransform(x, y)
	return (x - View.x) / View.zoomX, (y - View.y) / View.zoomY
end
function View.transform(x, y)
	return x * View.zoomX + View.x, y * View.zoomY + View.y
end

return View
