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

local function computeDimensions(text)
    local font = Comment.font or love.graphics.getFont()
    local maxLineWidth = 0
    local lineCount = 0

    if not text or text == "" then
        -- Provide minimal dimensions for an empty comment, e.g., for padding
        return 32, font:getHeight() + 32
    end

    for line in text:gmatch("[^\n]+") do
        lineCount = lineCount + 1
        maxLineWidth = math.max(maxLineWidth, font:getWidth(line))
    end

    -- Add padding to width and height
    return maxLineWidth + 32, lineCount * font:getHeight() + 32
end

function Comment.reflow(comment)
    local calculatedWidth, calculatedHeight = computeDimensions(comment.text)
    comment.w = calculatedWidth
    comment.h = calculatedHeight
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
    text = text or ""
    local calculatedWidth, calculatedHeight = computeDimensions(text)
    local comment = {
        x = x,
        y = y,
        w = calculatedWidth,
        h = calculatedHeight,
        text = text,
    }
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
