local Theme = {}

Theme.default = require("theme_default")

-- number of assignable note parts, see Edit.assignPart
Theme.PART_COUNT = 4

local function fromHex(rgba)
	local rb = tonumber(string.sub(rgba, 2, 3), 16)
	local gb = tonumber(string.sub(rgba, 4, 5), 16)
	local bb = tonumber(string.sub(rgba, 6, 7), 16)

	local r, g, b = love.math.colorFromBytes(rb, gb, bb)
	return { r, g, b }
end

-- convert every "#rrggbb" string in a theme, including nested ones (parts)
local function convertHex(t)
	for k, v in pairs(t) do
		if type(v) == "string" and string.sub(v, 1, 1) == "#" then
			t[k] = fromHex(v)
		elseif type(v) == "table" then
			convertHex(v)
		end
	end
end

local function copy(t)
	local new = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			new[k] = copy(v)
		else
			new[k] = v
		end
	end
	return new
end

local function luminance(c)
	return 0.3 * c[1] + 0.6 * c[2] + 0.1 * c[3]
end

-- mix a color towards white
local function tint(c, a)
	return { c[1] + (1 - c[1]) * a, c[2] + (1 - c[2]) * a, c[3] + (1 - c[3]) * a }
end

--[[
part colors may be written a few ways in user_themes.lua:
	parts = { "#ff8a2b", ... }
	parts = { { 1.0, 0.54, 0.17 }, ... }
	parts = { { color = "#ff8a2b", highlight = "#ffc46b" }, ... }
anything left out falls back to the built-in palette that suits the background.
run this after convertHex, colors are expected to be {r, g, b} by now.
]]
local function normalizeParts(th)
	local fallback = Theme.default.dark.parts
	if luminance(th.background) > 0.5 then
		fallback = Theme.default.light.parts
	end

	local given = th.parts or {}
	th.parts = {}
	for i = 1, Theme.PART_COUNT do
		local p = given[i]
		if type(p) ~= "table" then
			p = copy(fallback[i])
		elseif p[1] ~= nil then
			-- a bare color instead of a { color = ..., highlight = ... } pair
			p = { color = p }
		end
		if p.color == nil then
			p.color = copy(fallback[i].color)
		end
		if p.highlight == nil then
			p.highlight = tint(p.color, 0.45)
		end
		th.parts[i] = p
	end
end

function Theme.load()
	if love.filesystem.getInfo("user_themes.lua") then
		local contents, _ = love.filesystem.read("user_themes.lua")
		Theme.themes = loadstring(contents)()
	else
		local contents, _ = love.filesystem.read("theme_default.lua")
		love.filesystem.write("user_themes.lua", contents)
		Theme.themes = Theme.default
	end
	-- the built-in palettes are used as fallbacks, so they need converting
	-- even when the themes they belong to are not loaded
	convertHex(Theme.default.dark.parts)
	convertHex(Theme.default.light.parts)

	for _, th in pairs(Theme.themes) do
		-- mix in defaults if missing
		-- (parts are handled separately, they depend on the background)
		for k, v in pairs(Theme.default.dark) do
			if th[k] == nil and k ~= "parts" then
				th[k] = v
			end
		end

		-- convert hex to rgb
		convertHex(th)

		normalizeParts(th)
	end

	Theme.indices = {}
	for k in pairs(Theme.themes) do
		table.insert(Theme.indices, k)
	end
	table.sort(Theme.indices)

	Theme.index = 1
	Theme.setName("dark")

	if love.filesystem.getInfo("last_theme") then
		local name = love.filesystem.read("last_theme")
		Theme.setName(name)
	end

	Theme.setCurrent()
end

function Theme.next()
	Theme.index = Theme.index % #Theme.indices + 1
	Theme.setCurrent()
end

function Theme.setCurrent()
	setMessage("theme: " .. Theme.indices[Theme.index])
	Theme.current = Theme.themes[Theme.indices[Theme.index]]
end

function Theme.getName()
	return Theme.indices[Theme.index]
end

function Theme.setName(name)
	for i, v in ipairs(Theme.indices) do
		if v == name then
			Theme.index = i
		end
	end
end

return Theme
