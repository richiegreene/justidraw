-- don't remove this line!
local theme = {}

-- default dark theme
theme.dark = {
	-- triplets of colors {red, green, blue} in range 0.0 - 1.0
	background = { 0.0, 0.0, 0.0 },
	text = { 0.9, 0.9, 0.9 },
	envelope = { 0.8, 0.8, 0.8 },
	highlight = { 0.1, 0.8, 1.0 },
	playhead = { 0.7, 0.7, 0.7 },
	draw = { 0.8, 0.2, 0.2 },
	cursor = { 0.6, 0.6, 0.6 },

	vertices = { 0.8, 0.8, 0.8 },
	showVertices = true,

	-- up to four assignable parts, set with ctrl/cmd+alt+1 .. 4
	-- `color` replaces `envelope`, `highlight` replaces `highlight` for that note
	-- `highlight` is optional, a lighter tint of `color` is used when it is missing
	-- a theme without `parts` borrows the dark or light palette below,
	-- whichever suits its background
	parts = {
		{ color = "#ff8a2b", highlight = "#ffc46b" },
		{ color = "#3fcf6e", highlight = "#8cf0ae" },
		{ color = "#a472ff", highlight = "#cdb4ff" },
		{ color = "#ff4d7e", highlight = "#ff9fbb" },
	},

	grid = { 0.9, 0.9, 0.9 },
	showGridTime = true,
	showGridPitch = true,

	-- how far a muted part fades towards the background, 0.0 - 1.0
	muteFade = 0.75,

	-- width of the notes
	lineWidth = 65,

	showTooltip = true,
	showMeter = true,
}

theme.light = {
	background = { 0.95, 0.95, 0.95 },
	cursor = { 0.4, 0.4, 0.4 },
	text = { 0.1, 0.1, 0.1 },
	envelope = { 0.0, 0.0, 0.0 },
	grid = { 0.0, 0.0, 0.0 },
	highlight = { 1.0, 0.2, 0.4 },
	playhead = { 0.3, 0.3, 0.3 },
	draw = { 0.6, 0.2, 0.2 },
	vertices = { 0.2, 0.2, 0.2 },

	parts = {
		{ color = "#a85200", highlight = "#e88a1f" },
		{ color = "#1b6b36", highlight = "#35a85e" },
		{ color = "#4b2a99", highlight = "#7b5cd6" },
		{ color = "#a3123a", highlight = "#e04a6e" },
	},
}

theme.pink = {
	-- you can also use hex codes for the colors, using this format:
	background = "#ffdde1",
	text = "#642ca9",
	envelope = "#ff36ab",
	grid = "#ff74d4",
	highlight = "#642ca9",
	playhead = "#642ca9",
	cursor = "#642ca9",
	vertices = "#B231AA",

	parts = {
		{ color = "#d95f00", highlight = "#ff9a33" },
		{ color = "#147a5c", highlight = "#26b389" },
		{ color = "#2b4fc7", highlight = "#5c82ff" },
		{ color = "#8c0e2c", highlight = "#d13757" },
	},
}

theme.minimal = {
	envelope = { 1.0, 1.0, 1.0 },

	lineWidth = 80,

	showGridTime = false,
	showGridPitch = false,
	showTooltip = false,
	showMeter = false,
	showVertices = false,
}

-- don't remove this line!
return theme
