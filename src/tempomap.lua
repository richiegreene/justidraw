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
	bar <number> <x> <t> <num> <den> <beats> <divisions> <quarters>
	anchor <role> <bar> <beat> <x> <t> <bpm> <auto|tagged>

the last three words of a bar line were added after the first version and an
older reader simply does not see them, which is what the format is for. they say
what num and den cannot: 6/8 has two beats of three, not six of one, and a bar
of an anacrusis is as long as what was written in it rather than as long as its
metre asks for. anything that wants to place a *notated* position -- the divide
command does -- needs all three, and engrave has already worked them out.

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
TempoMap.showBeats = true
TempoMap.showSubdivisions = true

function TempoMap.clear()
	TempoMap.active = false
	TempoMap.bars = {}
	TempoMap.anchors = {}
	TempoMap.bpm = nil
	TempoMap.song = nil
	TempoMap.duration = 0
	TempoMap.source = nil
	TempoMap.showBeats = true
	TempoMap.showSubdivisions = true
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
		elseif head == "guides" then
			TempoMap.showBeats = w[2] ~= "no-beats"
			TempoMap.showSubdivisions = w[3] ~= "no-subdivisions"
		elseif head == "bar" and #w >= 4 then
			local number, x, t = num(w[2]), num(w[3]), num(w[4])
			if number and x and t then
				local beats = num(w[7]) or num(w[5]) or 4
				local quarters = num(w[9])
				if not quarters then
					-- an older engrave. the metre's own length is the best guess
					-- there is, and it is right for every bar but an anacrusis
					quarters = (num(w[5]) or 4) * 4 / (num(w[6]) or 4)
				end
				bars[#bars + 1] = {
					number = number,
					x = x,
					t = t,
					num = num(w[5]) or 4,
					den = num(w[6]) or 4,
					beats = math.max(1, beats),
					divisions = math.max(1, num(w[8]) or 2),
					quarters = quarters > 0 and quarters or 4,
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

--[[
the notated clock

everything above is in x, which is where things *are*. this is the other
question: where they are written. a bar of 4/4 has four beats in it whether the
player took two seconds over it or five, and a command that divides a bar into
five has to divide the writing and not the ruler -- otherwise a quintuplet over
a bar that slows down comes out as five even stretches of wall-clock time, which
is precisely the thing nobody plays and nobody wrote.

so: a position in quarters from the start of the piece, and a map from that to x
built out of every known point engrave sent. the bar lines are known because the
composer put them there. the anchors are known because engrave read them off the
notation against the recording -- a beat with a notehead on it carries the
instant that note actually sounded. between two known points there is nothing to
go on but evenness, and evenness is assumed only there.

this is the same construction tempo-map.js calls beatFrame, for the same reason,
and it has to be: the two programs are looking at one reading of one piece, and
a division placed here should land on the beat drawn there.
]]

-- the known (q, x) points, ascending, built once per parse
local frame = nil

-- a bar's own x-per-quarter, for closing off the last bar. taken from the bar
-- after it where there is one, since that is a measurement rather than a guess
local function xPerQuarterOf(bar)
	local bars = TempoMap.bars
	for i, b in ipairs(bars) do
		if b == bar then
			local nextBar = bars[i + 1]
			if nextBar then
				return (nextBar.x - b.x) / (b.quarters or 4)
			end
			local prevBar = bars[i - 1]
			if prevBar then
				return (b.x - prevBar.x) / (prevBar.quarters or 4)
			end
		end
	end
	return 100
end

local function buildFrame()
	frame = {}
	if #TempoMap.bars == 0 then
		return
	end

	-- q is cumulative, so the bars have to be walked in order and each one asked
	-- how long it is rather than assumed to be as long as the last
	local q = 0
	local qOf = {}
	for i, bar in ipairs(TempoMap.bars) do
		qOf[bar.number] = q
		frame[#frame + 1] = { q = q, x = bar.x }
		bar.q = q
		q = q + (bar.quarters or 4)
		bar.qEnd = q
	end
	-- the far edge of the last bar. without it every division inside that bar
	-- would interpolate against nothing and collapse onto the barline
	local last = TempoMap.bars[#TempoMap.bars]
	frame[#frame + 1] = { q = q, x = last.x + (last.quarters or 4) * xPerQuarterOf(last) }

	for _, a in ipairs(TempoMap.anchors) do
		local barQ = qOf[a.bar]
		local bar = TempoMap.barNumbered(a.bar)
		if barQ and bar then
			-- engrave sends `beat` as a 1-based count of beats, and a beat is the
			-- bar's length over its beat count -- which is not 4/den in compound
			-- time, which is why `beats` is sent at all
			local beatQ = (bar.quarters or 4) / (bar.beats or 4)
			local aq = barQ + (a.beat - 1) * beatQ
			if aq > barQ + 1e-6 and aq < (bar.qEnd or barQ) - 1e-6 then
				frame[#frame + 1] = { q = aq, x = a.x }
			end
		end
	end

	table.sort(frame, function(p1, p2)
		return p1.q < p2.q
	end)

	-- two points at one q would be a contradiction about where a position is,
	-- and would make the interpolation below divide by zero. keep the first
	local kept = {}
	for _, p in ipairs(frame) do
		local prev = kept[#kept]
		if not prev or p.q - prev.q > 1e-6 then
			kept[#kept + 1] = p
		end
	end
	frame = kept
end

function TempoMap.barNumbered(number)
	for _, b in ipairs(TempoMap.bars) do
		if b.number == number then
			return b
		end
	end
	return nil
end

-- the x a notated position falls at. evenness is assumed only between two
-- points that are actually known
function TempoMap.xForQ(q)
	if not frame then
		buildFrame()
	end
	if not frame or #frame == 0 then
		return nil
	end
	if q <= frame[1].q then
		return frame[1].x
	end
	if q >= frame[#frame].q then
		return frame[#frame].x
	end
	for i = 1, #frame - 1 do
		local a, b = frame[i], frame[i + 1]
		if q >= a.q and q <= b.q then
			local span = b.q - a.q
			if span < 1e-9 then
				return a.x
			end
			return a.x + ((q - a.q) / span) * (b.x - a.x)
		end
	end
	return frame[#frame].x
end

--[[
addressing a position inside the bars, by beat and by subdivision.

the composer says "b.2.3" and means the third sixteenth of the second beat, and
what that is in quarters depends entirely on the metre: the second beat of 4/4
starts one quarter in and its thirds-of-a-sixteenth are quarter-quarters, while
the second beat of 6/8 starts one and a half quarters in and divides in three.
neither is derivable from num and den without knowing which of the two the metre
is, and that is why `beats` and `divisions` are sent.

the numbering is the one a musician counts out loud. beats are 1..n. inside a
beat, .1 is the beat itself and the rest are what follows it: in simple time the
sixteenths, so .2 .3 .4 are e, +, a; in compound the eighths, so .2 .3 are la
and li. that is the same distinction `divisions` already carries, read at a
finer grain -- a simple beat is addressed in quarters of itself and a compound
one in thirds.

beats count on across a barline rather than restarting, so a stretch of two bars
of 4/4 is addressed b.1 through b.8. each bar is asked its own length on the way
past, so a metre change inside the stretch counts correctly rather than assuming
the first bar's beat all the way through.
]]

-- the bar a notated position falls in
function TempoMap.barAtQ(q)
	local found = nil
	for _, b in ipairs(TempoMap.bars) do
		if b.q and b.q <= q + 1e-6 then
			found = b
		end
	end
	return found or TempoMap.bars[1]
end

--[[
where the nth beat after `qA` starts, how long it is, and how it divides.

returns nil when the stretch does not have that many beats in it, which is a
thing to report rather than to clamp: asking for beat 6 of a bar of four is a
mistake about the music, and quietly giving back beat 4 would hide it.
]]
function TempoMap.beatStart(qA, n)
	if not frame then
		buildFrame()
	end
	if n < 1 then
		return nil
	end
	local bar = TempoMap.barAtQ(qA)
	if not bar then
		return nil
	end

	local q = qA
	local counted = 0
	for i = 1, #TempoMap.bars do
		local b = TempoMap.bars[i]
		if b.q and b.q + 1e-6 >= (bar.q or 0) then
			local beatQ = (b.quarters or 4) / (b.beats or 4)
			-- a stretch starting mid-bar counts only the beats still to come
			local from = math.max(q, b.q)
			local beatsHere = math.floor(((b.qEnd or (b.q + 4)) - from) / beatQ + 1e-6)
			if counted + beatsHere >= n then
				local subUnits = ((b.divisions or 2) == 3) and 3 or 4
				return from + (n - counted - 1) * beatQ, beatQ, subUnits, b
			end
			counted = counted + beatsHere
			q = b.qEnd or q
		end
	end
	return nil
end

--[[
one address -- a beat, or a beat and a subdivision of it -- as the stretch of
quarters it names.

a lone beat names the whole beat; a beat and a subdivision name that one
subdivision. so an address is always a span and never a point, which is what
lets "b.2" and "b.2.3" mean the obvious thing without a second syntax for
"and everything up to the next one".
]]
function TempoMap.addressSpan(qA, beat, sub)
	local q, beatQ, subUnits = TempoMap.beatStart(qA, beat)
	if not q then
		return nil
	end
	if not sub then
		return q, q + beatQ
	end
	if sub < 1 or sub > subUnits then
		return nil, "beat " .. beat .. " divides in " .. subUnits .. " here"
	end
	local unit = beatQ / subUnits
	return q + (sub - 1) * unit, q + sub * unit
end

--[[
the bars a stretch of x covers, opened out to whole bars.

a region is conceived between barlines -- that is what a bar is -- so a highlight
that clips the first note of a bar or trails a little past the last one means the
bar, and saying so here is what stops the composer having to place a selection to
the pixel. a highlight genuinely inside one bar and touching no barline still
means that bar.

returns the two notated positions, or nil when there is no map to ask.
]]
function TempoMap.barSpan(x0, x1)
	if not TempoMap.active or #TempoMap.bars == 0 then
		return nil
	end
	if not frame then
		buildFrame()
	end
	if x1 < x0 then
		x0, x1 = x1, x0
	end

	local bars = TempoMap.bars

	-- how much of a bar's edge counts as being on the barline rather than inside
	-- the bar. a highlight dragged to a barline is a highlight *up to* it: without
	-- this, letting go a pixel past the line takes in the whole of the next bar
	-- and divides two bars where the composer meant one
	local function edge(i)
		local b = bars[i]
		local w = bars[i + 1] and (bars[i + 1].x - b.x) or ((b.quarters or 4) * xPerQuarterOf(b))
		return math.max(1, w * 0.02)
	end

	-- the bar the left edge falls in: the last one starting at or before it
	local first, last = nil, nil
	for i, b in ipairs(bars) do
		if b.x <= x0 + edge(i) then
			first = i
		end
	end
	first = first or 1

	-- and the last bar the highlight reaches into, rather than merely up to
	last = first
	for i = first + 1, #bars do
		if bars[i].x < x1 - edge(i) then
			last = i
		else
			break
		end
	end

	local qA = bars[first].q
	local qB = bars[last].qEnd
	if not qA or not qB or qB <= qA then
		return nil
	end
	return qA, qB, bars[first].number, bars[last].number
end

-- the frame is derived from a reading and must not outlive one. wrapped rather
-- than folded into the originals because those are declared above `frame` is,
-- and a stale frame is a map of a piece that is no longer open
local parse_ = TempoMap.parse
function TempoMap.parse(text)
	frame = nil
	local ok = parse_(text)
	if ok then
		buildFrame()
	end
	return ok
end

local clear_ = TempoMap.clear
function TempoMap.clear()
	frame = nil
	return clear_()
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

-- a line for the status area. it names where the map came from because there
-- is more than one answer now: engrave reads barlines off a drawing that was
-- already made, connect-the-dots carries them over from the midi file a drawing
-- was made out of. same file, opposite directions, and worth telling apart when
-- the bars are not where you expected them
function TempoMap.describe()
	if not TempoMap.active then
		return "no tempo map"
	end
	local from = TempoMap.source or "elsewhere"
	return #TempoMap.bars .. " bars from " .. from
end

return TempoMap
