local Comment = require("tool_comment")
local SelectRect = {}

SelectRect.name = [[
rectangular selection
shift: add
ctrl: subtract
]]

SelectRect.select = true

function SelectRect.mousepressed()
	SelectRect.ix = mouseX
	SelectRect.iy = mouseY
end

function SelectRect.mousedown() end

function SelectRect.mousereleased()
	local mask = {}

	local x1, y1 = View.invTransform(SelectRect.ix, SelectRect.iy)
	local x2, y2 = View.invTransform(mouseX, mouseY)
	if x1 > x2 then
		x1, x2 = x2, x1
	end
	if y1 > y2 then
		y1, y2 = y2, y1
	end

	for i, v in ipairs(song.track[1]) do
		if x1 < v.x and v.x < x2 and y1 < v.y and v.y < y2 then
			mask[v] = true
		end
	end

	local selectedComment = nil
	for _, comment in ipairs(song.comments or {}) do
		local w = comment.w or Comment.width
		local h = comment.h or Comment.height
		if x2 > comment.x and x1 < comment.x + w and y2 > comment.y and y1 < comment.y + h then
			selectedComment = comment
			break
		end
	end

	if modifierKeys.ctrl or modifierKeys.cmd then
		if selectedComment and Comment.selected == selectedComment then
			Comment.selected = nil
		end
	elseif modifierKeys.shift then
		if selectedComment then
			Comment.selected = selectedComment
		end
	else
		Comment.selected = selectedComment
	end

	Selection.set(mask)
end

function SelectRect.draw()
	if mouseDown[1] and SelectRect.ix and SelectRect.iy then
		love.graphics.setColor(Theme.current.cursor)
		love.graphics.rectangle("line", SelectRect.ix, SelectRect.iy, mouseX - SelectRect.ix, mouseY - SelectRect.iy)
	end
end

return SelectRect
