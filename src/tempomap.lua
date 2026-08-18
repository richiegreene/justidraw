--[[
tempo maps handed over from engrave

the time grid this program draws is a fixed one: a line every 100 units, picked
out every 4th and every 16th. read against the time mapping in audio.lua that is
a semiquaver grid with a beat and a bar of four emphasised -- one tempo, one
metre, for the whole length of the piece.

that is the right grid when there is nothing better to say. once the composer has
taken the drawing into engrave and written barlines over it, there is: the bars
are where they put them, and they are not four beats apart at a constant speed.
so engrave writes the barlines it read into a sidecar file beside the .sav, and
this module reads them back and view.lua draws those instead.

the file is lines of words -- no json reader here and none wanted. a line either
has the shape its first word promises or it is skipped, so a file written by a
later engrave loses its unfamiliar lines and draws everything else. nothing in
here can throw.

	justidraw-tempomap 1
	source engrave
	song <name>
	bpm <n>
	duration <seconds>
	bar <number> <x> <t> <num> <den>
	anchor <role> <bar> <beat> <x> <t> <bpm> <auto|tagged>

x is the anchor and seconds is the reading, not the other way round. x is what
this program draws in, so a barline sent as x stays where it was put even if the
bpm is changed afterwards; sent as seconds it would drift away from the very
partial it was drawn against. the bpm it was converted with comes too, so we can
say when it no longer matches.
]]

local TempoMap = {}

TempoMap.suffix = ".tempomap"

-- is there a map loaded at all
TempoMap.active = false
-- does the composer want it drawn (ctrl+g)
TempoMap.show = true

TempoMap.bars = {}
TempoMap.anchors = {}
TempoMap.bpm = nil
TempoMap.song = nil
TempoMap.duration = 0
TempoMap.source = nil

function TempoMap.clear()
	TempoMap.active = false
	TempoMap.bars = {}
	TempoMap.anchors = {}
	TempoMap.bpm = nil
	TempoMap.song = nil
	TempoMap.duration = 0
	TempoMap.source = nil
end

-- the words of one line
local function words(line)
	local out = {}
	for w in line:gmatch("%S+") do
		out[#out + 1] = w
	end
	return out
end

local num = tonumber

function TempoMap.parse(text)
	TempoMap.clear()
	if type(text) ~= "string" or #text == 0 then
		return false
	end

	local bars = {}
	local anchors = {}
	local ok = false

	for line in text:gmatch("[^\r\n]+") do
		local w = words(line)
		local head = w[1]

		if head == "justidraw-tempomap" then
			ok = true
		elseif head == "source" then
			TempoMap.source = w[2]
		elseif head == "song" then
			TempoMap.song = w[2]
		elseif head == "bpm" then
			TempoMap.bpm = num(w[2])
		elseif head == "duration" then
			TempoMap.duration = num(w[2]) or 0
		elseif head == "bar" and #w >= 4 then
			local number, x, t = num(w[2]), num(w[3]), num(w[4])
			if number and x and t then
				bars[#bars + 1] = {
					number = number,
					x = x,
					t = t,
					num = num(w[5]) or 4,
					den = num(w[6]) or 4,
				}
			end
		elseif head == "anchor" and #w >= 6 then
			local x, t = num(w[5]), num(w[6])
			if x and t then
				anchors[#anchors + 1] = {
					role = w[2] or "beat",
					bar = num(w[3]) or 0,
					beat = num(w[4]) or 1,
					x = x,
					t = t,
					bpm = num(w[7]) or 0,
					tagged = w[8] == "tagged",
				}
			end
		end
	end

	-- a file with a header and nothing in it is not a map, it is an empty
	-- promise, and drawing nothing while claiming to be active would leave the
	-- plain grid off with no sign of why
	if not ok or (#bars == 0 and #anchors == 0) then
		TempoMap.clear()
		return false
	end

	table.sort(bars, function(a, b)
		return a.x < b.x
	end)
	table.sort(anchors, function(a, b)
		return a.x < b.x
	end)

	TempoMap.bars = bars
	TempoMap.anchors = anchors
	TempoMap.active = true
	return true
end

-- the sidecar's name for a save name, with or without the .sav on it
function TempoMap.nameFor(saveName)
	local name = saveName or ""
	name = name:gsub("%.sav$", "")
	return name .. TempoMap.suffix
end

--[[
look for the map belonging to a save, and load it if it is there.

called wherever a song is loaded. an absent sidecar is the ordinary case and not
a failure -- it means this drawing has not been engraved yet, and the plain grid
is what should be drawn.
]]
function TempoMap.loadFor(saveName)
	TempoMap.clear()
	local name = TempoMap.nameFor(saveName)
	if not love.filesystem.getInfo(name) then
		return false
	end
	local text = love.filesystem.read(name)
	if not TempoMap.parse(text) then
		return false
	end
	return true
end

-- whether the bpm has moved since engrave worked the x positions out. the
-- barlines are still where they were put; what has changed is what time they
-- fall at, which is worth saying once rather than silently
function TempoMap.staleBpm()
	if not TempoMap.active or not TempoMap.bpm or not song or not song.bpm then
		return false
	end
	return math.abs(TempoMap.bpm - song.bpm) > 1e-6
end

function TempoMap.toggle()
	if not TempoMap.active then
		return false
	end
	TempoMap.show = not TempoMap.show
	return TempoMap.show
end

-- a line for the status area
function TempoMap.describe()
	if not TempoMap.active then
		return "no tempo map"
	end
	return #TempoMap.bars .. " bars from engrave"
end

return TempoMap
