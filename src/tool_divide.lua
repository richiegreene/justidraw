--[[
divide -- re-articulating a stretch of drawing as a number of notes.

the drawing has no notes in it. it has lines: a chain of vertices carrying a
pitch and a width, and what makes two of them two notes rather than one is that
the chain stops and another starts, which is the only thing the synth in
audio.lua looks at. an attack is a beginning, and a beginning is a gap.

so this is what the command is. the composer highlights a stretch, says how many
notes they want to hear in it, and every line crossing it is cut at those points:
the piece before each cut is closed off a little early and faded, and a new chain
opens at the cut carrying on from the pitch and the width the old one had there.
nothing is retuned and nothing is re-shaped -- the long swell across a bar is
still the same swell, it has simply been articulated. that is the difference
between this and drawing four notes: the material is kept and only its
punctuation changes.

where the cuts go is the whole question, and it is why this belongs next to the
tempo map rather than in edit.lua. dividing a bar into four means four *notated*
quarters, and the four quarters of a bar that slows down are not four equal
stretches of the page. engrave has already read where the beats of that bar
actually fall -- that is what the anchors in the sidecar are -- so the division
is placed on the notated clock and converted through those readings. ask for four
in a bar of 4/4 and the cuts land on the beats engrave drew; ask for five and they
land where five evenly written notes would fall between the same readings, which
is a quintuplet and not five equal slices of wall clock.

with no tempo map there is nothing to be notated against and the stretch is cut
evenly in x, which is the honest fallback and is said out loud when it happens.

what the notes then *sound* like is the second half of the command, in brackets
after the rhythm: a gain in decibels and an envelope for each note. both add to
the drawing rather than replacing it, which is the same principle as the cutting
-- the composer drew this material and asked for it to be articulated, not
overwritten -- so a swell across a bar is still that swell after being cut into
thirty-seconds, shaped and lifted six decibels.
]]

Divide = {}

-- how much silence to put in front of an attack, as a fraction of the note it
-- is articulating, and the bounds that fraction is held between in x units.
-- short enough to read as an articulation rather than a rest, long enough that
-- the synth's own smoothing does not swallow it whole
Divide.gapFraction = 0.12
Divide.gapMin = 6
Divide.gapMax = 40

-- the last count asked for, offered again next time
Divide.text = "4"

--[[
what the composer typed.

	16              sixteenths, across the whole of the highlighted bars
	b.2, 32         thirty-seconds, across beat 2 only
	b.2.3, 32       across the third sixteenth of beat 2 (the + of 2)
	b.2-4.3, 32     from the downbeat of 2 to the + of 4
	b.2, 5:4        five against four, across beat 2
	5:4             five against four, across the whole of it
	b.1-3, 5x       five notes across beats 1 and 2 -- a range runs *to* its
	                far address, so b.1-3 stops where beat 3 starts

the number is a note *value* and not a count: 16 means sixteenths, so what it
comes to depends on how much music it is asked to cover. sixteenths across a bar
of 4/4 is sixteen notes and sixteenths across one beat of it is four, which is
the point -- the composer is naming a rhythm rather than counting holes.

a count is still sometimes what is meant, and `5x` is how to say it: five notes
across whatever the address covers, whatever they would be called. that is why 5
on its own is refused -- there is no such thing as a fifth-note, and guessing
which of the two was meant is worse than asking.

a comma separates the address from what to do to it, and the colon is left alone
for the thing musicians already spell with one: 5:4 is five against four, and it
has to be able to follow an address like everything else can. `b.2, 5:4` is a
quintuplet on the second beat, and nothing in the line has to be read twice to
see which half is which.
]]

--[[
the shape a division may be given: how loud, and what each note's amplitude does
across its own length.

	32 (+6dB)          every new note six decibels over what was drawn
	32 (0158)          shaped, at the loudness already there
	32 (+6dB; 0158)    both
	32 (5-15dB; 0158)  a crescendo, +5dB at the start of the stretch to +15 at
	                   the end of it -- across all the notes, not inside each

the decibels are *added to* what the drawing already does. this program has no
absolute level: a line's width is its loudness, the composer drew it that way on
purpose, and a command that set a level rather than adding one would flatten the
phrasing it was asked to articulate. so the figure is a gain, the drawn shape
survives it, and a ramp is a crescendo over the whole stretch rather than a new
dynamic imposed on each note.

the four digits are attack, decay, sustain, release, 0 to 9, and 0 is always the
small or quick end of whatever that parameter measures -- three of them are times
and the third is a level, and saying "0 is fast or small" covers both without
having to remember which is which. they scale to the note they are shaping, so
one setting sounds like itself on a semibreve and on a thirty-second: an attack
of 3 is a proportion of the note, not a number of milliseconds that would swallow
the short one whole.

the envelope multiplies rather than replaces, for the same reason the decibels
add. a note cut out of a swell keeps the swell.
]]

local ADSR_LIMITS = {
	attack = { 0.004, 0.40 },
	decay = { 0.010, 0.40 },
	sustain = { 0.05, 1.00 },
	release = { 0.010, 0.50 },
}

local function lerp(a, b, f)
	return a + (b - a) * f
end

local function digitTo(limits, digit)
	return lerp(limits[1], limits[2], math.max(0, math.min(9, digit)) / 9)
end

-- "+6dB", "6dB", "-3dB", "5-15dB", "25-2dB". returns the two ends of the ramp,
-- which are the same figure where it is not a ramp
local function readGain(text)
	local s = text:gsub("^%+", "")
	local a, b = s:match("^([%+%-]?%d+%.?%d*)%-([%+%-]?%d+%.?%d*)[dD][bB]$")
	if a then
		a, b = tonumber(a), tonumber(b)
		if a and b then
			return a, b
		end
		return nil
	end
	local only = s:match("^([%+%-]?%d+%.?%d*)[dD][bB]$")
	if only then
		local n = tonumber(only)
		if n then
			return n, n
		end
	end
	return nil
end

--[[
what was in the brackets.

returns a shape table, or nil with a reason. an empty bracket is a shape that
does nothing and is treated as a mistake rather than obeyed, since nobody types
one on purpose.
]]
function Divide.readShape(text)
	text = (text or ""):gsub("%s+", "")
	local shape = { db0 = 0, db1 = 0 }
	local said = {}
	local any = false

	for part in (text .. ";"):gmatch("(.-);") do
		if part ~= "" then
			local digits = part:match("^(%d%d%d%d)$")
			if digits then
				shape.attack = tonumber(digits:sub(1, 1))
				shape.decay = tonumber(digits:sub(2, 2))
				shape.sustain = tonumber(digits:sub(3, 3))
				shape.release = tonumber(digits:sub(4, 4))
				said[#said + 1] = digits
				any = true
			else
				local a, b = readGain(part)
				if not a then
					return nil, "in brackets: a gain like +6dB or 5-15dB, and four digits like 0158"
				end
				shape.db0, shape.db1 = a, b
				said[#said + 1] = (a == b) and string.format("%+gdB", a)
					or string.format("%+g to %+gdB", a, b)
				any = true
			end
		end
	end

	if not any then
		return nil, "nothing in those brackets"
	end
	shape.said = table.concat(said, ", ")
	return shape
end

local VALUES = { [1] = true, [2] = true, [4] = true, [8] = true, [16] = true, [32] = true, [64] = true }

-- one address: `2`, or `2.3`
local function readAddress(text)
	local beat, sub = text:match("^(%d+)%.(%d+)$")
	if beat then
		return tonumber(beat), tonumber(sub)
	end
	beat = text:match("^(%d+)$")
	if beat then
		return tonumber(beat), nil
	end
	return nil
end

--[[
split what was typed into an address and a value.

returns address (or nil for the whole stretch) and the value text.
]]
function Divide.split(text)
	local s = (text or ""):gsub("%s+", "")
	local head, tail = s:match("^[bB]%.(.-),(.+)$")
	if not head then
		-- an address with no comma after it is half a line, and the composer
		-- meant to finish it. saying so beats dividing the whole bar instead
		if s:match("^[bB]%.") then
			return nil, s, "b.2 what? try b.2, 16"
		end
		return nil, s
	end

	local a, b = head:match("^(.-)%-(.+)$")
	local spec
	if a then
		local ab, asub = readAddress(a)
		local bb, bsub = readAddress(b)
		if not ab or not bb then
			return nil, s, "an address looks like b.2, b.2.3 or b.2-4.3"
		end
		spec = { fromBeat = ab, fromSub = asub, toBeat = bb, toSub = bsub, range = true }
	else
		local ab, asub = readAddress(head)
		if not ab then
			return nil, s, "an address looks like b.2, b.2.3 or b.2-4.3"
		end
		spec = { fromBeat = ab, fromSub = asub }
	end
	return spec, tail
end

--[[
how many notes a value comes to over a stretch of `quarters`.

a value is a denominator against the semibreve, so its length in quarters is
4/value and the count is the one that falls out of that. it has to come out
whole: sixteenths do not fit across a dotted beat, and a stretch that cannot
hold a whole number of them is a question about the music rather than a
rounding error.
]]
function Divide.readValue(text, quarters, beatsInSpan)
	local s = (text or ""):gsub("%s+", "")

	local x = s:match("^(%d+)[xX]$")
	if x then
		local n = tonumber(x)
		if n and n >= 2 then
			return n, s
		end
		return nil, s, "a count looks like 5x, and has to be two or more"
	end

	--[[
	n against m.

	the stretch the composer addressed *is* the time of m -- that is what
	addressing it was for -- so n against m across it is n notes, and 5:4 on a
	beat is five in the time of that beat. where the stretch holds a whole
	number of m the group repeats instead, so 5:4 across a bar of four beats is
	five and across two such bars is ten, which is the reading that makes a
	tuplet written once cover what was highlighted rather than stretch across it.
	]]
	local n, m = s:match("^(%d+)[:/](%d+)$")
	if n and m then
		n, m = tonumber(n), tonumber(m)
		if not (n and m and n > 1 and m > 0) then
			return nil, s, "n against m looks like 5:4, with n two or more"
		end
		local groups = 1
		if beatsInSpan then
			local g = beatsInSpan / m
			if g >= 1 - 1e-6 and math.abs(g - math.floor(g + 0.5)) < 1e-3 then
				groups = math.floor(g + 0.5)
			end
		end
		return n * groups, s
	end

	local value = tonumber(s)
	if not value or value ~= math.floor(value) or not VALUES[value] then
		return nil, s, "a note value: 1 2 4 8 16 32 64, or a count like 5x"
	end

	local count = quarters * value / 4
	local whole = math.floor(count + 0.5)
	if whole < 1 or math.abs(count - whole) > 1e-3 then
		return nil, s, string.format("%d does not fit that stretch evenly", value)
	end
	return whole, s
end

-- the x range the current selection covers-- the x range the current selection covers
local function selectedSpan()
	local x0, x1
	for _, v in ipairs(Selection.list) do
		if not x0 or v.x < x0 then
			x0 = v.x
		end
		if not x1 or v.x > x1 then
			x1 = v.x
		end
	end
	return x0, x1
end

--[[
the stretch of notated time the command acts on.

the highlight names the bars -- that is what a bar is for -- and the address, if
there is one, names a part of them. so a composer who wants a bar of thirty-
seconds highlights it and types 32, and one who wants only its second beat
highlighted the same bar and types b.2: 32. the highlight is not asked to be
accurate to the beat, because a drawing has nothing in it to snap a highlight to
and the composer would be aiming at a place rather than at a thing.

returns the two notated positions, and what to call the stretch when reporting.
]]
function Divide.region(x0, x1, spec)
	local qA, qB, firstBar, lastBar = TempoMap.barSpan(x0, x1)
	if not qA then
		return nil
	end

	local where
	if firstBar == lastBar then
		where = "bar " .. firstBar
	else
		where = "bars " .. firstBar .. "-" .. lastBar
	end

	if not spec then
		return qA, qB, where
	end

	local q0, err = TempoMap.addressSpan(qA, spec.fromBeat, spec.fromSub)
	if not q0 then
		return nil, nil, nil, err or ("there is no beat " .. spec.fromBeat .. " in " .. where)
	end
	local _, q1 = TempoMap.addressSpan(qA, spec.fromBeat, spec.fromSub)

	if spec.range then
		local r0, r1 = TempoMap.addressSpan(qA, spec.toBeat, spec.toSub)
		if not r0 then
			return nil, nil, nil, "there is no beat " .. spec.toBeat .. " in " .. where
		end
		-- a range runs to the start of its far address, not through it: "b.2-4.3"
		-- is everything from the downbeat of 2 up to the + of 4, which is where
		-- the composer stopped counting
		q1 = r0
	end

	if not q1 or q1 <= q0 + 1e-6 then
		return nil, nil, nil, "that address has no length"
	end

	-- an address names a place inside what was highlighted, and beats count on
	-- past a barline, so b.9 over one highlighted bar of 4/4 would otherwise
	-- resolve quietly into a bar the composer never selected and divide nothing
	-- they could see. the highlight is the subject; the address only narrows it
	if q0 < qA - 1e-6 or q1 > qB + 1e-6 then
		return nil, nil, nil, "that address runs past " .. where
	end

	local said = "b." .. spec.fromBeat .. (spec.fromSub and ("." .. spec.fromSub) or "")
	if spec.range then
		said = said .. "-" .. spec.toBeat .. (spec.toSub and ("." .. spec.toSub) or "")
	end
	return q0, q1, said .. " of " .. where
end

--[[
the cuts, as x positions.

there is one at the start of the stretch as well as at every division inside it,
and one at the far end. the inner ones are the rhythm; the two ends are what make
the stretch a stretch -- articulating the second beat of a bar means the beat
begins where it begins and stops where it stops, and without those the first note
would still be joined to beat one and the last would run on into beat three.
they cost nothing where the line already breaks there, since cutting a chain at
its own beginning does nothing.
]]
function Divide.cuts(q0, q1, count)
	local cuts = {}
	local span = q1 - q0
	for k = 0, count do
		local x = TempoMap.xForQ(q0 + (span * k) / count)
		if x then
			cuts[#cuts + 1] = x
		end
	end
	return cuts
end

-- the same stretch cut evenly in x, for when there is no map to be notated
-- against. said out loud by the caller rather than done quietly
function Divide.evenCuts(x0, x1, count)
	local cuts = {}
	for k = 0, count do
		cuts[#cuts + 1] = x0 + ((x1 - x0) * k) / count
	end
	return cuts
end

-- the vertex on this chain at or before x-- the vertex on this chain at or before x, or nil when the chain starts later
local function vertexBefore(head, x)
	local v, found = head, nil
	while v and v.x <= x + 1e-9 do
		found = v
		v = v.r
	end
	return found
end

-- pitch and width read off the line at x, between the two vertices it lies
-- between. this is what keeps the amplitude shape: a new attack does not start
-- from a level of its own, it starts from whatever the line was already doing
local function sampleAt(a, b, x)
	if not b then
		return a.y, a.w
	end
	local span = b.x - a.x
	if span < 1e-9 then
		return a.y, a.w
	end
	local f = (x - a.x) / span
	return a.y + f * (b.y - a.y), a.w + f * (b.w - a.w)
end

--[[
cut one chain at one x.

two separate placements, and they have to be separate. the attack goes exactly
at x, because that is the musical event and it is the thing that was asked for.
the silence in front of it starts a gap earlier, which is somewhere else
entirely -- possibly several vertices back on a densely drawn line -- and the
vertices caught between the two are what the silence is made of, so they come
out.

both new vertices are interpolated where they land rather than snapped to the
nearest neighbour, so the line comes out of the operation drawing the curve it
drew going in, minus the bite. the attack carries the width the line already had
at that instant: an articulation of the material, not a new note at a level of
its own, which is what keeps a swell a swell across all the notes cut out of it.

the gap is never allowed to eat more than half of the note in front of it. a
short note near a wide gap would otherwise be swallowed whole, and a division
that silently deletes material is not a division.

`doomed` collects what to drop; the caller removes it all in one pass, because
these run over every selected line at once.
]]
local function cutChain(head, x, gap, doomed)
	local a = vertexBefore(head, x)
	if not a then
		return nil
	end

	local track = song.track[1]

	-- the attack. a vertex already sitting on x is used as it stands
	local newHead
	if math.abs(x - a.x) < 1e-9 then
		if not a.l then
			return nil -- the line already begins here; nothing to articulate
		end
		newHead = a
	else
		local b = a.r
		if not b then
			return nil -- the line has already ended before this division
		end
		local y, w = sampleAt(a, b, x)
		newHead = { x = x, y = y, w = w, part = b.part or a.part, l = a, r = b }
		a.r = newHead
		b.l = newHead
		track[#track + 1] = newHead
	end

	-- how far back the silence reaches, held to half of what is in front
	local tailX = x - gap
	local firstOfNote = newHead.l
	while firstOfNote and firstOfNote.l do
		firstOfNote = firstOfNote.l
	end
	if firstOfNote then
		local half = (firstOfNote.x + x) * 0.5
		if tailX < half then
			tailX = half
		end
	end

	-- everything between the silence and the attack goes
	local p = newHead.l
	while p and p.x > tailX + 1e-9 do
		doomed[p] = true
		p = p.l
	end

	if not p then
		-- nothing left in front: the division falls on the very start of a line,
		-- which is already an attack. undo the bite rather than empty the note
		for q in pairs(doomed) do
			doomed[q] = nil
		end
		newHead.l = nil
		return newHead
	end

	if math.abs(tailX - p.x) < 1e-9 then
		-- the fade lands on a vertex that is already there
		p.w = 0
		p.r = nil
	else
		local after = p.r
		local ty = p.y
		if after then
			ty = select(1, sampleAt(p, after, tailX))
		end
		local tail = { x = tailX, y = ty, w = 0, part = p.part, l = p }
		p.r = tail
		track[#track + 1] = tail
	end

	newHead.l = nil
	return newHead
end

--[[
put a vertex on a line at x, between the two it falls between.

used to give an envelope somewhere to turn. a note four vertices long has
nowhere to put an attack and a decay, and scaling the four it has would give a
shape that depends on how densely the composer happened to draw rather than on
what they asked for.
]]
local function insertBetween(head, x)
	local a = vertexBefore(head, x)
	if not a or not a.r then
		return nil
	end
	if math.abs(a.x - x) < 1e-9 then
		return a
	end
	local b = a.r
	if math.abs(b.x - x) < 1e-9 then
		return b
	end
	if x <= a.x or x >= b.x then
		return nil
	end
	local y, w = sampleAt(a, b, x)
	local v = { x = x, y = y, w = w, part = a.part, l = a, r = b }
	a.r = v
	b.l = v
	song.track[1][#song.track[1] + 1] = v
	return v
end

--[[
shape one note.

the envelope is worked out as a proportion of this note's own length, so the
same four digits mean the same thing on a long note and a short one -- which is
the only way a setting typed once can apply to a stretch of thirty-seconds and a
stretch of minims alike.

the three times are held to the note between them. a release of 9 on a note that
also has a slow attack would otherwise run backwards through it, and an envelope
whose parts overlap is not a shape, it is an argument.
]]
local function shapeNote(head, shape, gainAt)
	local verts = {}
	local v = head
	while v do
		verts[#verts + 1] = v
		v = v.r
	end
	if #verts < 2 then
		return false
	end

	local s = verts[1].x
	local e = verts[#verts].x
	local L = e - s
	if L <= 1e-9 then
		return false
	end

	local env
	if shape.attack then
		local at = digitTo(ADSR_LIMITS.attack, shape.attack) * L
		local dt = digitTo(ADSR_LIMITS.decay, shape.decay) * L
		local rt = digitTo(ADSR_LIMITS.release, shape.release) * L
		local sustain = digitTo(ADSR_LIMITS.sustain, shape.sustain)

		local total = at + dt + rt
		if total > L * 0.95 then
			local k = (L * 0.95) / total
			at, dt, rt = at * k, dt * k, rt * k
		end

		-- somewhere for each corner to be, so the shape is drawn and not merely
		-- sampled wherever the line's own vertices happen to sit
		for _, bx in ipairs({ s + at, s + at + dt, e - rt }) do
			if bx > s + 1e-9 and bx < e - 1e-9 then
				insertBetween(head, bx)
			end
		end

		env = function(x)
			local t = x - s
			if t <= at then
				return at > 1e-9 and (t / at) or 1
			elseif t <= at + dt then
				return dt > 1e-9 and lerp(1, sustain, (t - at) / dt) or sustain
			elseif t <= L - rt then
				return sustain
			else
				return rt > 1e-9 and sustain * ((L - t) / rt) or 0
			end
		end
	end

	-- re-walked, because the breakpoints above joined the chain
	verts = {}
	v = head
	while v do
		verts[#verts + 1] = v
		v = v.r
	end

	local clipped = false
	for i, p in ipairs(verts) do
		local w = p.w
		if env then
			w = w * env(p.x)
		end
		w = w * gainAt(p.x)
		if w > 1 then
			w = 1
			clipped = true
		end
		p.w = math.max(0, w)
	end
	-- a note still has to end. the release brings it to nothing on its own, but
	-- a shape with no envelope must not have its closing zero scaled into a step
	verts[#verts].w = 0
	return clipped
end

--[[
decibels, as a multiplier on *width*.

the synth squares the width to get an amplitude -- amp_curve in audio.lua is
x*x -- so width is not amplitude and the usual 10^(dB/20) is the wrong power
here. it would deliver twice the decibels asked for, quietly, and the mistake
would be invisible: everything would simply be louder than it said.

so the square comes out in the exponent. a width of w sounds at w^2, a gain of
g decibels wants w^2 * 10^(g/10), and the width that gives is w * 10^(g/40).
]]
function Divide.widthRatio(db)
	return 10 ^ (db / 40)
end

--[[
how much louder the drawing can go before it runs out of width.

width is held to 1 everywhere in this program, so the headroom over a stretch is
set by how wide it already is -- and a composer asking for +25dB over material
drawn at half width is asking for something the format cannot hold. worth saying
in decibels, which is what they were thinking in.
]]
local function headroomDb(peakW)
	if peakW <= 1e-6 then
		return 99
	end
	return 40 * math.log(1 / peakW, 10)
end

--[[
the gain at an x, as a multiplier on width.

decibels are a ratio and the drawing is already at some level, so this multiplies
what is there. the ramp is read across the whole divided stretch rather than
within each note, which is what makes it a crescendo over the bar instead of a
swell repeated on every thirty-second.
]]
local function gainFunction(shape, startX, endX)
	if not shape then
		return function()
			return 1
		end
	end
	local span = endX - startX
	return function(x)
		local f = span > 1e-9 and math.max(0, math.min(1, (x - startX) / span)) or 0
		return Divide.widthRatio(lerp(shape.db0, shape.db1, f))
	end
end

--[[
divide a stretch into notes.

`cuts` are x positions; the first and last of them are the ends of the stretch.
]]
function Divide.run(cuts, said, shape)
	if #cuts < 2 then
		setMessage("nothing to divide there")
		return
	end
	local startX, endX = cuts[1], cuts[#cuts]

	-- the shortest note this makes, which is what the gap is measured against so
	-- that dividing into thirty-seconds does not put thirty-two near-silences in
	-- a row
	local shortest = endX - startX
	for i = 2, #cuts do
		shortest = math.min(shortest, cuts[i] - cuts[i - 1])
	end
	local gap = math.max(Divide.gapMin, math.min(Divide.gapMax, shortest * Divide.gapFraction))

	-- every chain the selection touches, taken by its head, so a chain selected
	-- in the middle is still divided across the whole stretch
	local heads, seen = {}, {}
	for _, v in ipairs(Selection.list) do
		local h = v
		while h.l do
			h = h.l
		end
		if not seen[h] and not Edit.isLocked(h) then
			seen[h] = true
			heads[#heads + 1] = h
		end
	end

	local doomed = {}
	local made = 0
	for _, head in ipairs(heads) do
		local at = head
		for _, x in ipairs(cuts) do
			if x >= startX - 1e-9 and x <= endX + 1e-9 then
				local nextHead = cutChain(at, x, gap, doomed)
				if nextHead then
					at = nextHead
					made = made + 1
				end
			end
		end
	end

	if made == 0 then
		setMessage("no line crosses those divisions")
		return
	end

	-- one pass over the track rather than one per vertex: a dense drawing
	-- divided finely produces thousands of these, and table.remove in a loop
	-- over that is the difference between instant and a visible stall
	if next(doomed) then
		local track = song.track[1]
		local j = 0
		for i = 1, #track do
			local v = track[i]
			if doomed[v] then
				Selection.mask[v] = nil
			else
				j = j + 1
				track[j] = v
			end
		end
		for i = #track, j + 1, -1 do
			track[i] = nil
		end
	end

	Edit.removeSingles()

	--[[
	shaping, once the notes exist.

	done by finding the heads inside the stretch rather than by remembering what
	cutChain handed back, because a division that fell on a line's own beginning
	makes no new head and yet that note is as much part of the stretch as the
	ones that were cut. a head exactly at the far end is the material *after* the
	stretch and is left alone.
	]]
	local clipped = false
	-- taken before anything is scaled: afterwards every clipped vertex reads 1
	-- and the headroom would come out as nothing whatever was asked for
	local peakBefore = 0
	if shape then
		for _, v in ipairs(song.track[1]) do
			if v.x >= startX - 1e-6 and v.x < endX - 1e-6 then
				peakBefore = math.max(peakBefore, v.w or 0)
			end
		end
		local gainAt = gainFunction(shape, startX, endX)
		local shaped = 0
		for _, v in ipairs(song.track[1]) do
			if not v.l and v.x >= startX - 1e-6 and v.x < endX - 1e-6 then
				if shapeNote(v, shape, gainAt) then
					clipped = true
				end
				shaped = shaped + 1
			end
		end
		if shaped == 0 then
			shape = nil
		end
	end

	Selection.refresh()
	Undo.register()

	local msg = "divided " .. said .. " -- " .. made .. " attacks"
	if shape then
		msg = msg .. " (" .. shape.said .. ")"
		if clipped then
			msg = msg .. string.format(" -- clipped; about %+.0fdB fits here", headroomDb(peakBefore))
		end
	end
	setMessage(msg)
end

-- ctrl/cmd+d: ask what to divide into, then do it
function Divide.startEditing()
	if Selection.isEmpty() then
		setMessage("highlight something to divide")
		return
	end
	textEntered = Divide.text
	textInput = true
	textEditTarget = Divide
	textInputLabel = "divide (16 | b.2, 32 | 32 (+6dB; 0158)):"
end

-- called by main.lua when the field is committed
function Divide.commit(text)
	if Selection.isEmpty() then
		setMessage("highlight something to divide")
		return
	end
	local x0, x1 = selectedSpan()
	if not x0 or x1 - x0 < 1e-6 then
		setMessage("that highlight has no width")
		return
	end

	-- the bracket comes off first, so neither the address nor the value has to
	-- know it might be followed by one
	local body = (text or ""):gsub("%s+", "")
	local shape = nil
	local inner = body:match("%((.*)%)$")
	if inner then
		body = body:gsub("%b()$", "")
		local got, why = Divide.readShape(inner)
		if not got then
			setMessage(why)
			return
		end
		shape = got
	elseif body:find("%(") then
		setMessage("that bracket is not closed")
		return
	end

	local spec, valueText, err = Divide.split(body)
	if err then
		setMessage(err)
		return
	end

	if not TempoMap.active then
		-- nothing to be notated against. a value has no meaning without a metre,
		-- so only a plain count can be honoured, and it is cut evenly in x
		local count = Divide.readValue(valueText, 4, 4)
		if not count then
			setMessage("no tempo map -- only a count like 5x can be divided here")
			return
		end
		Divide.text = text
		Divide.run(Divide.evenCuts(x0, x1, count), "the selection, evenly -- no tempo map", shape)
		return
	end

	local q0, q1, said, regionErr = Divide.region(x0, x1, spec)
	if not q0 then
		setMessage(regionErr or "nothing to divide there")
		return
	end

	local quarters = q1 - q0
	-- how many beats the stretch holds, for the n:m form
	local beats = nil
	local bar = TempoMap.barAtQ(q0)
	if bar then
		beats = quarters / ((bar.quarters or 4) / (bar.beats or 4))
	end

	local count, _, valueErr = Divide.readValue(valueText, quarters, beats)
	if not count then
		setMessage(valueErr or "divide: a note value, or a count like 5x")
		return
	end

	Divide.text = text
	Divide.run(Divide.cuts(q0, q1, count), said .. " into " .. count, shape)
end

return Divide
