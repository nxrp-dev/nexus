function drawControlFrame(canvas, x, y, width, height, frameColor)
    canvas:Color(frameColor)
    canvas:Rectangle(x, y, width, height)

    if width > 3 and height > 3 then
        canvas:Color(0xFF3DAEE9)
        canvas:Line(x + 1, y + 1, x + 1, y + height - 2)
    end
end
