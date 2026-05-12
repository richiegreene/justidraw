local Comment = {}

Comment.name = "comment"
Comment.width = 1100
Comment.height = 500
Comment.selected = nil
Comment.dragging = false
Comment.dragOffsetX = 0
Comment.dragOffsetY = 0
Comment.fontSize = 320
Comment.font = nil

function Comment.init()
    if not song.comments then
        song.comments = {}
    end
    if not Comment.font then
        Comment.font = love.graphics.newFont(Comment.fontSize)
    end
end

local function computeTextHeight(text, width)
    local font = Comment.font or love.graphics.getFont()
    local maxLineWidth = 0
    local lineCount = 0

    for line in text:gmatch("[^\n]+") do
        lineCount = lineCount + 1
        maxLineWidth = math.max(maxLineWidth, font:getWidth(line))
    end

    if lineCount == 0 then
        lineCount = 1
    end

    local wrapLines = math.max(1, math.ceil(maxLineWidth / math.max(1, width - 16)))
    return 16 + lineCount * wrapLines * font:getHeight()
end

function Comment.reflow(comment)
    comment.w = comment.w or Comment.width
    comment.h = computeTextHeight(comment.text or "", comment.w)
    if comment.h < Comment.height then
        comment.h = Comment.height
    end
end

function Comment.find(x, y)
    local wx, wy = View.invTransform(x, y)
    for i = #song.comments, 1, -1 do
        local comment = song.comments[i]
        local w = comment.w or Comment.width
        local h = comment.h or Comment.height
        if wx >= comment.x and wx <= comment.x + w and wy >= comment.y and wy <= comment.y + h then
            return comment
        end
    end
end

function Comment.select(comment)
    Comment.selected = comment
end

function Comment.add(x, y, text)
    text = text or "new note"
    local comment = {
        x = x,
        y = y,
        w = Comment.width,
        text = text,
    }
    Comment.reflow(comment)
    table.insert(song.comments, comment)
    Comment.selected = comment
    return comment
end

function Comment.mousepressed()
    if mouseDown[1] then
        local comment = Comment.find(mouseX, mouseY)
        if comment then
            Comment.selected = comment
            Comment.dragging = true
            local wx, wy = View.invTransform(mouseX, mouseY)
            Comment.dragOffsetX = wx - comment.x
            Comment.dragOffsetY = wy - comment.y
        else
            local wx, wy = View.invTransform(mouseX, mouseY)
            local newComment = Comment.add(wx, wy)
            Comment.startEditing(newComment)
        end
    end
end

function Comment.mousedown()
    if Comment.dragging and Comment.selected then
        local wx, wy = View.invTransform(mouseX, mouseY)
        Comment.selected.x = wx - Comment.dragOffsetX
        Comment.selected.y = wy - Comment.dragOffsetY
    end
end

function Comment.mousereleased()
    Comment.dragging = false
end

function Comment.draw()
    love.graphics.push()
    love.graphics.translate(View.x, View.y)
    love.graphics.scale(View.zoomX, View.zoomY)

    for _, comment in ipairs(song.comments or {}) do
        Comment.reflow(comment)

        local x = comment.x
        local y = comment.y
        local w = comment.w
        local h = comment.h

        local bg = Theme.current.background
        love.graphics.setColor(bg[1], bg[2], bg[3], 0.92)
        love.graphics.rectangle("fill", x, y, w, h, 8)

        if comment == Comment.selected then
            love.graphics.setColor(Theme.current.highlight)
        else
            love.graphics.setColor(Theme.current.cursor)
        end
        love.graphics.rectangle("line", x, y, w, h, 8)

        local prevFont = love.graphics.getFont()
        love.graphics.setFont(Comment.font)
        love.graphics.setColor(Theme.current.text)
        love.graphics.printf(comment.text or "", x + 16, y + 16, w - 32)
        love.graphics.setFont(prevFont)
    end

    love.graphics.pop()
end

function Comment.startEditing(comment)
    textEntered = comment.text or ""
    textInput = true
    textEditTarget = comment
    textInputLabel = "comment text:"
end

function Comment.removeSelected()
    if Comment.selected then
        for i, comment in ipairs(song.comments or {}) do
            if comment == Comment.selected then
                table.remove(song.comments, i)
                Comment.selected = nil
                return
            end
        end
    end
end

return Comment
