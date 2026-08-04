--[[
interface to track structure
adding notes, cleanup etc
]]

Edit = {}

function Edit.addNote(list)
	local pts = {}

	for i, v in ipairs(list) do
		local pt = {}
		pt.x = v[1]
		pt.y = v[2]
		pt.w = v[3]

		pts[i] = pt
	end

	local first = pts[1]
	local last = pts[#pts]

	for i, v in ipairs(pts) do
		if pts[i - 1] then
			pts[i].l = pts[i - 1]
		end
		if pts[i + 1] then
			pts[i].r = pts[i + 1]
		else
			--set final to 0
			pts[i].w = 0
		end
		table.insert(song.track[1], pts[i])
	end

	-- a locked note must not be joined onto, so only automerge with the rest
	local candidates = Edit.editable()

	for i, v in ipairs(candidates) do
		if not v.l then
			local dist = math.sqrt((last.x - v.x) ^ 2 + (last.y - v.y) ^ 2)
			if dist < automergeDist and v ~= first then
				Edit.merge(last, v, true)
				break
			end
		end
	end

	for i, v in ipairs(candidates) do
		if not v.r then
			local dist = math.sqrt((first.x - v.x) ^ 2 + (first.y - v.y) ^ 2)
			if dist < automergeDist and v ~= last then
				Edit.merge(v, first)
				break
			end
		end
	end
end

function Edit.getNote(vert)
	local tbl = {}
	if vert then
		while vert.l do
			vert = vert.l
		end

		while vert do
			table.insert(tbl, vert)

			vert = vert.r
		end
	end

	return tbl
end

function Edit.add(list)
	for i, v in ipairs(list) do
		table.insert(song.track[1], v)
	end
end

--[[
parts
a note can be tagged with a part number (1 .. Theme.PART_COUNT) to draw it in
its own color. `part == nil` means unassigned, which draws with the theme
defaults. the tag sits on every vertex of the note so that it survives
splitting, erasing, resampling and duplicating.
]]

-- how far the cursor may be from a note when nothing is selected (pixels)
local PART_PICK_DIST = 60

function Edit.setNotePart(vert, part)
	for _, v in ipairs(Edit.getNote(vert)) do
		v.part = part
	end
end

-- first vertex of every note touched by the selection
function Edit.selectedNotes()
	local seen = {}
	local heads = {}
	for v in pairs(Selection.mask) do
		while v.l do
			v = v.l
		end
		if not seen[v] then
			seen[v] = true
			table.insert(heads, v)
		end
	end
	return heads
end

function Edit.noteAtCursor()
	local d = PART_PICK_DIST
	local found = nil
	for _, v in ipairs(Edit.editable()) do
		local x, y = View.transform(v.x, v.y)
		local dist = math.sqrt((mouseX - x) ^ 2 + (mouseY - y) ^ 2)
		if dist < d then
			found = v
			d = dist
		end
	end
	return found
end

function Edit.assignPart(part)
	local notes = Edit.selectedNotes()
	if #notes == 0 then
		local v = Edit.noteAtCursor()
		if v then
			notes = { v }
		end
	end
	if #notes == 0 then
		setMessage("select a note to assign a part")
		return
	end

	-- assigning the part a note already has toggles it back to default
	if part then
		local same = true
		for _, v in ipairs(notes) do
			if v.part ~= part then
				same = false
			end
		end
		if same then
			part = nil
		end
	end

	for _, v in ipairs(notes) do
		Edit.setNotePart(v, part)
	end

	if part then
		setMessage("part " .. part)
	else
		setMessage("part: none")
	end
	Undo.register()
end

--[[
parts that are silenced during playback, keyed by part number, with 0 standing
in for the unassigned notes. like the echo/reverb/preview switches this is a
session setting, it is not written to the save file.
]]
Edit.mutedParts = {}
local anyMuted = false

-- a muted part is locked: it still shows, greyed out, but it cannot be
-- selected or edited, so it stays put as a backdrop to work against
function Edit.isLocked(vert)
	return Edit.mutedParts[vert.part or 0] == true
end

-- the vertices the tools are allowed to touch. with nothing muted this is the
-- track itself, so the usual case costs nothing
function Edit.editable()
	if not anyMuted then
		return song.track[1]
	end
	local list = {}
	for _, v in ipairs(song.track[1]) do
		if not Edit.mutedParts[v.part or 0] then
			list[#list + 1] = v
		end
	end
	return list
end

function Edit.toggleMute(part)
	local i = part or 0
	local name = part and ("part " .. part) or "unassigned"

	if Edit.mutedParts[i] then
		Edit.mutedParts[i] = nil
		setMessage(name .. ": unmuted")
	else
		Edit.mutedParts[i] = true
		-- locking notes that are currently selected would leave them editable
		-- through the selection, so drop them from it
		for v in pairs(Selection.mask) do
			if (v.part or 0) == i then
				Selection.mask[v] = nil
			end
		end
		Selection.refresh()
		setMessage(name .. ": muted (locked)")
	end

	anyMuted = false
	for _ in pairs(Edit.mutedParts) do
		anyMuted = true
	end
end

-- select every note in the project belonging to a part (nil selects the
-- notes that have not been assigned to one)
function Edit.selectPart(part)
	local name = part and ("part " .. part) or "unassigned"

	if Edit.mutedParts[part or 0] then
		setMessage(name .. " is muted (locked)")
		return
	end

	local mask = {}
	local count = 0
	for _, v in ipairs(song.track[1]) do
		if v.part == part then
			mask[v] = true
			if not v.l then
				count = count + 1
			end
		end
	end

	if count == 0 then
		setMessage("nothing in " .. name)
		return
	end

	Selection.setNormal(mask)
	setMessage("selected " .. name .. " (" .. count .. (count == 1 and " note)" or " notes)"))
	Undo.register()
end

function Edit.join()
	if #Selection.list == 0 then
		setMessage("selection is empty")
		return
	end
	local vset = {}
	local vlist = {}
	for v in pairs(Selection.mask) do
		while v.l do
			v = v.l
		end
		if not vset[v] then
			vset[v] = true
			table.insert(vlist, v)
		end
	end

	if #vlist <= 1 then
		setMessage("select at least two notes to join")
		return
	end

	table.sort(vlist, function(a, b)
		return a.x < b.x
	end)

	if #vlist == 2 then
		local v1 = vlist[1]
		local v2 = vlist[2]

		while v1.r do
			v1 = v1.r
		end
		Edit.merge(v1, v2)
	else -- More than two notes selected, use intelligent pairing
		local acceptedJoins = Edit.findIntelligentPairs(vlist)

		if #acceptedJoins == 0 then
			setMessage("No suitable pairs found for intelligent join.")
			return
		end

		for _, join_pair in ipairs(acceptedJoins) do
			Edit.merge(join_pair.v_last_A, join_pair.v_first_B)
		end
	end

	Selection.deselect()
	Edit.resampleAll() -- Resample after all intelligent merges
end

function Edit.merge(v1, v2)
	assert(not v1.r)
	assert(not v2.l)

	local newx = (v1.x + v2.x) * 0.5

	if v1.l.x < newx and newx < v2.r.x then
		-- the note on the left keeps its part, so joining overrides the one
		-- on the right. an unassigned left note inherits instead of wiping.
		local part = v1.part or v2.part

		v1.x = newx
		v1.y = (v1.y + v2.y) * 0.5
		v1.w = math.max(v1.w, v2.w)

		v1.r = v2.r
		v2.r.l = v1

		Edit.setNotePart(v1, part)

		for i, v in ipairs(song.track[1]) do
			if v == v2 then
				table.remove(song.track[1], i)
				Selection.mask[v] = nil
				break
			end
		end
	end
	Selection.refresh()
end

function Edit.collapse(index)
	local v = song.track[1][index]

	if v.l and v.r then
		v.l.r = v.r
		v.r.l = v.l
	end

	table.remove(song.track[1], index)
	Selection.mask[v] = nil
	Selection.refresh()
end

function Edit.remove(verts)
	for i = #song.track[1], 1, -1 do
		local v = song.track[1][i]
		if verts[v] then
			if v.l then
				v.l.w = 0
				v.l.r = nil
			end
			if v.r then
				v.r.l = nil
			end
			table.remove(song.track[1], i)
			Selection.mask[v] = nil
		end
	end
	Edit.removeSingles()
end

function Edit.removeSingles()
	for i = #song.track[1], 1, -1 do
		local v = song.track[1][i]
		if not (v.l or v.r) then
			table.remove(song.track[1], i)
			Selection.mask[v] = nil
		end
	end
	Selection.refresh()
end

function Edit.getTangent(pt)
	if not pt.l then
		return (pt.y - pt.r.y) / (pt.x - pt.r.x)
	elseif not pt.r then
		return (pt.l.y - pt.y) / (pt.l.x - pt.x)
	else
		return (pt.l.y - pt.r.y) / (pt.l.x - pt.r.x)
	end
end

function Edit.resampleAll()
	local list = {}
	for i, v in ipairs(song.track[1]) do
		if not v.l then
			table.insert(list, v)
		end
	end

	while true do
		local count = 0
		for i, v in ipairs(list) do
			while v.r do
				local nextv = v.r

				local dx = v.r.x - v.x

				if dx < 0 then
					v.r = nil
					nextv.l = nil
				elseif dx > 80 then
					local nx = (v.x + v.r.x) * 0.5
					local ny = (v.y + v.r.y) * 0.5
					local nw = (v.w + v.r.w) * 0.5

					local new = { x = nx, y = ny, w = nw, part = v.part }

					v.r = new
					nextv.l = new
					new.l = v
					new.r = nextv

					table.insert(song.track[1], new)
					if Selection.mask[v] then
						Selection.mask[new] = true
					end
					count = count + 1
				end

				v = nextv
			end
		end
		if count == 0 then
			break
		end
	end
	Edit.removeSingles()

	Selection.refresh()
end

local PITCH_WEIGHT = 10 -- Higher weight for pitch difference
local TIME_WEIGHT = 1   -- Lower weight for time difference

function Edit.findIntelligentPairs(vlist)
    local joinCandidates = {} -- Stores {v_last_A, v_first_B, cost, note_A_id, note_B_id}

    -- Get unique note IDs for tracking
    local noteIds = {}
    for i, v_first in ipairs(vlist) do
        noteIds[v_first] = i -- Map first vertex to a unique ID for the note
    end

    -- Generate all potential join candidates
    for i, v_first_A in ipairs(vlist) do
        local v_last_A = v_first_A
        while v_last_A.r do v_last_A = v_last_A.r end -- Find last vertex of note A

        for j, v_first_B in ipairs(vlist) do
            if i ~= j then -- Don't join a note to itself
                if v_last_A.x < v_first_B.x then -- Note A must end before Note B starts
                    local pitchDiff = math.abs(v_last_A.y - v_first_B.y)
                    local timeDiff = v_first_B.x - v_last_A.x -- Always positive due to previous check

                    local cost = (pitchDiff * PITCH_WEIGHT) + (timeDiff * TIME_WEIGHT)

                    table.insert(joinCandidates, {
                        v_last_A = v_last_A,
                        v_first_B = v_first_B,
                        cost = cost,
                        note_A_id = i,
                        note_B_id = j
                    })
                end
            end
        end
    end

    -- Sort candidates by cost (ascending)
    table.sort(joinCandidates, function(a, b)
        return a.cost < b.cost
    end)

    local acceptedJoins = {}
    local notesInvolved = {} -- Track notes that are already part of an accepted join

    for _, candidate in ipairs(joinCandidates) do
        if not notesInvolved[candidate.note_A_id] and not notesInvolved[candidate.note_B_id] then
            table.insert(acceptedJoins, {
                v_last_A = candidate.v_last_A,
                v_first_B = candidate.v_first_B
            })
            notesInvolved[candidate.note_A_id] = true
            notesInvolved[candidate.note_B_id] = true
        end
    end

    return acceptedJoins
end
