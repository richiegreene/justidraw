--[[
loudness -- decibels over a highlight, flat or ramped.

the same figure the divide command takes in brackets, on its own and answering
to nothing but the selection. divide has to know where the barlines are, because
a rhythm is a notated thing; this does not, because a crescendo is not. the
composer sweeps a region of the drawing and says +6dB, or 5-15dB, and that is
the whole of it -- no metre, no map, no bars, and it works on a drawing that has
never been near engrave.

	+6dB      six decibels louder, across the whole highlight
	-3        three quieter; the dB is optional, there is nothing else it
	          could mean
	5-15dB    a crescendo, +5dB at the left edge of the highlight to +15 at
	          the right
	25-2dB    a diminuendo

it applies to the vertices that are selected and not to the notes they belong
to, which is what makes a ramp mean something: a highlight is a region of the
drawing and its two edges are where the composer put them. sweeping half a note
and asking for a crescendo shapes that half.

adding rather than setting, for the reason gain.lua gives: the width of a line
is what the composer drew, and a level imposed over it would flatten the
phrasing this is meant to shape.
]]

Loudness = {}

-- the last figure asked for, offered again next time
Loudness.text = "+6dB"

-- the x range the selected vertices cover
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
apply a figure to the selection.

a vertex whose width is already zero is left alone. those are the closing points
of notes and the silences between them, and a gain applied to them would open
the note's own ending back up -- multiplying zero keeps it zero, which is exactly
the behaviour wanted, but it is worth saying that it is deliberate rather than
an accident of the arithmetic.
]]
function Loudness.apply(db0, db1)
	local x0, x1 = selectedSpan()
	if not x0 then
		return 0, false, 0
	end

	local peakBefore = 0
	for _, v in ipairs(Selection.list) do
		peakBefore = math.max(peakBefore, v.w or 0)
	end

	local touched, clipped = 0, false
	for _, v in ipairs(Selection.list) do
		if not Edit.isLocked(v) then
			local w = (v.w or 0) * Gain.rampAt(db0, db1, v.x, x0, x1)
			if w > 1 then
				w = 1
				clipped = true
			end
			v.w = math.max(0, w)
			touched = touched + 1
		end
	end
	return touched, clipped, peakBefore
end

-- cmd/ctrl+l: ask for the figure, then apply it
function Loudness.startEditing()
	if Selection.isEmpty() then
		setMessage("highlight something to change the loudness of")
		return
	end
	textEntered = Loudness.text
	textInput = true
	textEditTarget = Loudness
	textInputLabel = "loudness (+6dB, or 5-15dB):"
end

-- called by main.lua when the field is committed
function Loudness.commit(text)
	if Selection.isEmpty() then
		setMessage("highlight something to change the loudness of")
		return
	end

	local db0, db1, said = Gain.read(text)
	if not db0 then
		setMessage("a gain like +6dB, -3dB or 5-15dB")
		return
	end

	local touched, clipped, peakBefore = Loudness.apply(db0, db1)
	if touched == 0 then
		setMessage("nothing in that highlight can be changed")
		return
	end

	Loudness.text = text
	Undo.register()

	local msg = said .. " over " .. touched .. " point" .. (touched == 1 and "" or "s")
	if clipped then
		msg = msg .. string.format(" -- clipped; about %+.0fdB fits here", Gain.headroom(peakBefore))
	end
	setMessage(msg)
end

return Loudness
