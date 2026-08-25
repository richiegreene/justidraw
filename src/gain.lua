--[[
gain -- decibels over what is already drawn.

shared by the two commands that take a loudness figure: the bracket on a divide
and the amplitude command on its own. one file because a decibel has to mean the
same thing in both, and because the conversion below is the one thing about this
program's amplitude that is easy to get wrong.

WIDTH IS NOT AMPLITUDE. a vertex carries a width, and the synth squares it --
amp_curve in audio.lua is x*x -- so the amplitude a line sounds at is w^2. the
usual 10^(dB/20) therefore does not apply to w. a gain of g decibels wants
w^2 * 10^(g/10), and the width that gives is w * 10^(g/40). getting this wrong
delivers exactly twice the decibels asked for and nothing on screen says so:
everything is simply louder than it claimed to be.

the figure is always a gain and never a level. this program has no absolute
loudness -- a line's width is what the composer drew, deliberately -- so a
command that set a level would flatten the phrasing it was asked to work on.
adding to it keeps the drawing and moves it.
]]

Gain = {}

-- the width that sounds `db` louder than a width of 1. see the note above
function Gain.widthRatio(db)
	return 10 ^ (db / 40)
end

--[[
how much louder a stretch can go before it runs out of width.

width is held to 1 everywhere in this program, so the headroom is set by how wide
the material already is: something drawn at half width has about +12dB in it and
no more. worth saying in decibels, since that is what the composer was thinking
in when they asked for too much.
]]
function Gain.headroom(peakW)
	if peakW <= 1e-6 then
		return 99
	end
	return 40 * math.log(1 / peakW, 10)
end

--[[
read a figure: "+6dB", "6", "-3dB", "5-15dB", "25-2dB".

the dB is optional because there is nothing else it could be, and a range is
written with a dash because that is how a composer says one. returns the two
ends -- the same figure twice where it is not a ramp -- and how to say it back.
]]
function Gain.read(text)
	local s = (text or ""):gsub("%s+", ""):gsub("[dD][bB]$", "")
	if s == "" then
		return nil
	end
	s = s:gsub("^%+", "")

	local a, b = s:match("^([%+%-]?%d+%.?%d*)%-([%+%-]?%d+%.?%d*)$")
	if not a then
		a = s:match("^([%+%-]?%d+%.?%d*)$")
		b = a
	end
	a, b = tonumber(a), tonumber(b)
	if not a or not b then
		return nil
	end

	local said = (a == b) and string.format("%+gdB", a)
		or string.format("%+g to %+gdB", a, b)
	return a, b, said
end

-- the width multiplier at x, along a ramp from x0 to x1
function Gain.rampAt(db0, db1, x, x0, x1)
	local span = x1 - x0
	local f = span > 1e-9 and math.max(0, math.min(1, (x - x0) / span)) or 0
	return Gain.widthRatio(db0 + (db1 - db0) * f)
end

return Gain
