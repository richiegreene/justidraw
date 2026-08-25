local binser = require("lib/binser")
local nouns = require("res/nouns")
local adjectives = require("res/adjectives")

File = {}

local PART_META_SUFFIX = ".parts"

local function partMetaName(name)
	return name:gsub("%.sav$", PART_META_SUFFIX)
end

local function encodePartMeta(value)
	return tostring(value or ""):gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\n", "\\n")
end

local function decodePartMeta(value)
	return value:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\\\", "\\")
end

function File.loadPartMetadata(name)
	partMetadata = {}
	local data = love.filesystem.read(partMetaName(name))
	if not data then return end
	for line in data:gmatch("[^\r\n]+") do
		local number, category, label = line:match("^(%d+)\t([^\t]*)\t(.*)$")
		number = tonumber(number)
		if number and number >= 1 and number <= 32 then
			partMetadata[number] = { category = decodePartMeta(category), name = decodePartMeta(label) }
		end
	end
end

function File.savePartMetadata(name)
	local lines = {}
	for number = 1, 32 do
		local meta = partMetadata and partMetadata[number]
		if meta and (meta.name or meta.category) then
			lines[#lines + 1] = table.concat({ number, encodePartMeta(meta.category), encodePartMeta(meta.name) }, "\t")
		end
	end
	love.filesystem.write(partMetaName(name), table.concat(lines, "\n"))
end

function File.save()
	song.version_major = VERSION_MAJOR
	song.version_minor = VERSION_MINOR
	local filename = song.name .. ".sav"

	love.filesystem.write(filename, binser.serialize(song))
	File.savePartMetadata(filename)
	love.filesystem.write("last_save", filename)
	setMessage("saved: " .. filename)
end

function File.loadLast()
	if love.filesystem.getInfo("last_save") then
		local name = love.filesystem.read("last_save")
		if love.filesystem.getInfo(name) then
			File.read(love.filesystem.read(name))
			File.loadTempoMap(name)
			File.loadPartMetadata(name)
			setMessage("loaded last save: " .. name)
			return
		end
	else
		love.filesystem.write("last_save", "a")
	end
	setMessage("no last save found")
end

--[[
look for the barlines engrave left beside a save.

this is the whole of the seam on this side. engrave writes the sidecar into the
save folder before it launches us, so by the time we open the .sav the map is
already sitting next to it under the same name -- see tempomap.lua. an absent
one is the ordinary case: it means this drawing has not been engraved yet, and
the plain grid is the right thing to draw.
]]
function File.loadTempoMap(name)
	if not TempoMap then
		return
	end
	if TempoMap.loadFor(name) then
		TempoMap.show = true
		setMessage(TempoMap.describe() .. " (ctrl+g for the plain grid)")
	end
end

function File.randomName()
	return adjectives[math.random(#adjectives)] .. " " .. nouns[math.random(#nouns)]
end

function File.newSong()
	local new = {}
	-- versioned save files
	new.version_major = VERSION_MAJOR
	new.version_minor = VERSION_MINOR
	new.bpm = 120
	new.bpmOffset = 0
	new.track = {}
	new.track[1] = {}
	new.gain = 0.125
	new.comments = {}
	new.name = File.randomName()
	new.synth = 1
	return new
end

function File.new()
	song = File.newSong()
	partMetadata = {}
	Edit.clearMutes()
	File.setTitle()
end

function File.load(f)
	local filename = f:getFilename()
	local name = filename:match("[^/\\]*.sav$")
	name = name:sub(0, #name - 4)

	f:open("r")
	local data = f:read()
	File.read(data)

	song.name = name
	File.loadTempoMap(name)
	File.loadPartMetadata(filename)
	File.setTitle()
end

function File.setName(name)
	song.name = name
	File.setTitle()
end

function File.setTitle()
	love.window.setTitle("justidraw (" .. song.name .. ")")
end

function File.read(f)
	local file = binser.deserialize(f)[1]
	Edit.clearMutes()

	-- backwards compatibility housekeeping
	if not file.version_major then
		file.version_major = 0
	end
	if not file.version_minor then
		file.version_minor = 2
	end

	if file.version_major ~= VERSION_MAJOR or file.version_minor ~= VERSION_MINOR then
		local message = "loaded song saved with a previous version! ("
			.. file.version_major
			.. "."
			.. file.version_minor
			.. ")"
		setMessage(message)
		print(message)
	end

	song = File.newSong()
	for k, v in pairs(file) do
		song[k] = v
	end

	if not song.synth then
		song.synth = 1
	end

	if not song.comments then
		song.comments = {}
	end

	-- remove any NaNs
	local to_remove = {}
	for _, track in ipairs(song.track) do
		for i, v in ipairs(track) do
			if v.x ~= v.x or v.y ~= v.y or v.w ~= v.w then
				print(i, "NaN")
				to_remove[v] = true
			end
		end
	end
	Edit.remove(to_remove)

	Undo.register()

	File.setTitle()
end
