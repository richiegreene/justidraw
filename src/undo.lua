Undo = {}

Undo.maxSize = 50

-- Copy the graph iteratively so long linked notes cannot exhaust the Lua stack.
function deepcopy(orig, copies)
	if type(orig) ~= "table" then
		return orig
	end

	copies = copies or {}
	if copies[orig] then
		return copies[orig]
	end

	local root = {}
	copies[orig] = root
	local pending = { { source = orig, target = root } }

	local function copyValue(value)
		if type(value) ~= "table" then
			return value
		end
		if copies[value] then
			return copies[value]
		end
		local copy = {}
		copies[value] = copy
		pending[#pending + 1] = { source = value, target = copy }
		return copy
	end

	while #pending > 0 do
		local frame = table.remove(pending)
		local metatable = getmetatable(frame.source)
		if metatable then
			setmetatable(frame.target, copyValue(metatable))
		end
		for key, value in next, frame.source, nil do
			frame.target[copyValue(key)] = copyValue(value)
		end
	end

	return root
end

function Undo.load()
	Undo.stack = {}
	Undo.index = 0
	Undo.register()
end

function Undo.register()
	Undo.index = Undo.index + 1
	for i = #Undo.stack, Undo.index, -1 do
		Undo.stack[i] = nil
	end
	local t = {}
	t.song = deepcopy(song)
	t.selection = Selection.getIndices()
	Undo.stack[Undo.index] = t

	if #Undo.stack > Undo.maxSize then
		table.remove(Undo.stack, 1)
		Undo.index = Undo.index - 1
	end
end

function Undo.undo()
	Undo.index = Undo.index - 1
	if Undo.index >= 1 then
		song = deepcopy(Undo.stack[Undo.index].song)
		Selection.setFromIndices(Undo.stack[Undo.index].selection)

		-- title can change
		File.setTitle()
	else
		Undo.index = 1
		setMessage("nothing to undo!")
	end
end

function Undo.redo()
	Undo.index = Undo.index + 1
	if Undo.stack[Undo.index] then
		song = deepcopy(Undo.stack[Undo.index].song)
		Selection.setFromIndices(Undo.stack[Undo.index].selection)

		-- title can change
		File.setTitle()
	else
		Undo.index = #Undo.stack
		setMessage("nothing to redo!")
	end
end
