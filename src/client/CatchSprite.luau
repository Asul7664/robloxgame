-- One supplied portrait per mount. No reward remotes; no external asset IDs needed.
-- Native: EditableImage. Portable fallback: low-resolution UIGradient strips.
-- The owner limits the cache to two portraits, including their native images.
local AssetService = game:GetService("AssetService")
local Catalog = require(script.Parent:WaitForChild("CatchArtCatalog"))
local Sprite = {}
local function decodeBase64(encoded)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #alphabet do lookup[string.byte(alphabet, i)] = i - 1 end
    local clean = string.gsub(encoded, "%s", "")
    local output = buffer.create(math.floor(#clean * 3 / 4))
    local accumulator, bits, count = 0, 0, 0
    for i = 1, #clean do
        local byte = string.byte(clean, i)
        local value = lookup[byte]
        if value ~= nil then
            accumulator = accumulator * 64 + value; bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local power = 2 ^ bits
                buffer.writeu8(output, count, math.floor(accumulator / power))
                count = count + 1; accumulator = accumulator % power
            end
        else
            assert(byte == 61, "Invalid embedded portrait base64")
        end
    end
    return output, count
end
function Sprite.Decode(data)
    assert(type(data) == "table" and data.Width > 0 and data.Height > 0, "Invalid portrait size")
    local runs, length = decodeBase64(data.Pixels)
    assert(length % 2 == 0, "Incomplete portrait run")
    local total, pixel = data.Width * data.Height, 0
    local pixels = buffer.create(total * 4)
    for offset = 0, length - 1, 2 do
        local count = buffer.readu8(runs, offset)
        local color = data.Palette[buffer.readu8(runs, offset + 1) + 1]
        assert(count > 0 and color ~= nil and pixel + count <= total, "Corrupt portrait color run")
        for _ = 1, count do buffer.writeu32(pixels, pixel * 4, color); pixel = pixel + 1 end
    end
    assert(pixel == total, "Incorrect portrait pixel count")
    if data.Alphas then
        local alphaRuns, alphaLength = decodeBase64(data.Alphas)
        assert(alphaLength % 2 == 0, "Incomplete portrait alpha run")
        pixel = 0
        for offset = 0, alphaLength - 1, 2 do
            local count = buffer.readu8(alphaRuns, offset)
            local alpha = buffer.readu8(alphaRuns, offset + 1)
            assert(count > 0 and pixel + count <= total, "Corrupt portrait alpha")
            for _ = 1, count do buffer.writeu8(pixels, pixel * 4 + 3, alpha); pixel = pixel + 1 end
        end
        assert(pixel == total, "Incorrect portrait alpha count")
    end
    return pixels
end
local function sample(data, pixels, x, y, resolution)
    local sx = math.min(data.Width - 1, math.floor((x + 0.5) * data.Width / resolution))
    local sy = math.min(data.Height - 1, math.floor((y + 0.5) * data.Height / resolution))
    local offset = (sy * data.Width + sx) * 4
    return Color3.fromRGB(buffer.readu8(pixels, offset), buffer.readu8(pixels, offset+1), buffer.readu8(pixels, offset+2)),
        1 - buffer.readu8(pixels, offset+3) / 255
end
local function makeFallback(root, data, pixels, alive, known)
    -- <=20 strictly ordered keypoints in every sequence; at most 1,024 strips.
    local resolution, stripHeight = 128, 18
    local result = Instance.new("Frame")
    result.Name = "PortablePicture"; result.Size = UDim2.fromScale(1,1)
    result.BackgroundTransparency = 1; result.Visible = false; result.ZIndex = 3; result.Parent = root
    local count = 0
    for x = 0, resolution - 1 do
        for y = 0, resolution - 1, stripHeight do
            if not alive() then result:Destroy(); return nil end
            local height = math.min(stripHeight, resolution - y)
            local colors, alphas, visible = {}, {}, false
            for row = 0, height - 1 do
                local color, transparency = sample(data, pixels, x, y+row, resolution)
                colors[row+1], alphas[row+1] = known==false and Color3.fromRGB(37,54,65) or color, transparency
                if transparency < 0.999 then visible = true end
            end
            if visible then
                local colorKeys = {ColorSequenceKeypoint.new(0, colors[1])}
                local alphaKeys = {NumberSequenceKeypoint.new(0, alphas[1])}
                for row = 1, height do
                    local t = (row - 0.5) / height
                    table.insert(colorKeys, ColorSequenceKeypoint.new(t, colors[row]))
                    table.insert(alphaKeys, NumberSequenceKeypoint.new(t, alphas[row]))
                end
                table.insert(colorKeys, ColorSequenceKeypoint.new(1, colors[height]))
                table.insert(alphaKeys, NumberSequenceKeypoint.new(1, alphas[height]))
                local strip = Instance.new("Frame")
                strip.Name = "Strip"; strip.BorderSizePixel = 0
                strip.BackgroundColor3 = Color3.new(1,1,1); strip.ZIndex = 3
                strip.Position = UDim2.fromScale(x / resolution, y / resolution)
                strip.Size = UDim2.fromScale(1 / resolution, height / resolution)
                local gradient = Instance.new("UIGradient")
                gradient.Rotation = 90; gradient.Color = ColorSequence.new(colorKeys)
                gradient.Transparency = NumberSequence.new(alphaKeys)
                gradient.Parent = strip; strip.Parent = result
                count = count + 1
                if count % 48 == 0 then task.wait() end
            end
        end
    end
    result:SetAttribute("StripCount", count); result.Visible = true
    return result
end
function Sprite.Has(species) return Catalog.Has(species) end
function Sprite.Mount(parent, species, forcePortable, known)
    local root = Instance.new("Frame")
    root.Name = "Portrait_" .. species; root.Size = UDim2.fromScale(1,1)
    root.BackgroundTransparency = 1; root.ZIndex = 3; root.Parent = parent
    local state = {Species=species, Root=root, Ready=false, Mode="loading", Dead=false, Image=nil}
    local function alive() return not state.Dead and root.Parent ~= nil end
    function state:SetVisible(value) if not self.Dead then self.Root.Visible = value end end
    function state:Destroy()
        if self.Dead then return end
        self.Dead = true
        if self.Image then self.Image:Destroy(); self.Image = nil end
        if self.Root then self.Root:Destroy() end
    end
    task.spawn(function()
        local ok, data = pcall(Catalog.Get, species)
        local pixels
        if ok then ok, pixels = pcall(Sprite.Decode, data) end
        if not ok then
            if alive() then
                state.Mode = "error"; state.Ready = true
                warn("[QuietCove] Portrait decode failed: " .. species .. ": " .. tostring(pixels or data))
            end
            return
        end
        if not alive() then return end
        local label, editable
        local nativeOK = false
        if not forcePortable then
            nativeOK = pcall(function()
                editable = AssetService:CreateEditableImage({Size=Vector2.new(data.Width,data.Height)})
                assert(editable, "EditableImage budget unavailable")
                editable:WritePixelsBuffer(Vector2.zero, Vector2.new(data.Width,data.Height), pixels)
                label = Instance.new("ImageLabel")
                label.Name = "ApprovedCatchPicture"; label.Size = UDim2.fromScale(1,1)
                label.BackgroundTransparency = 1; label.ScaleType = Enum.ScaleType.Fit
                label.ImageColor3 = known==false and Color3.fromRGB(37,54,65) or Color3.new(1,1,1)
                label.ImageContent = Content.fromObject(editable); label.ZIndex = 3; label.Parent = root
            end)
        end
        if nativeOK then
            state.Image = editable; state.Mode = "EditableImage"
        else
            if label then label:Destroy() end
            if editable then editable:Destroy() end
            local fallbackOK, fallback = pcall(makeFallback, root, data, pixels, alive, known)
            if not alive() then return end
            if fallbackOK and fallback then state.Mode = "PortablePicture"
            else
                state.Mode = "error"
                warn("[QuietCove] Portrait fallback failed: " .. species .. ": " .. tostring(fallback))
            end
        end
        if alive() then root:SetAttribute("Renderer",state.Mode); state.Ready=true end
    end)
    return state
end
return Sprite
