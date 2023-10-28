local parseXml = require "loxel.lib.xml"

local function sortFramesByIndices(prefix, postfix)
    local s, e = #prefix + 1, -#postfix - 1
    return function(a, b)
        return string.sub(a.name, s, e) < string.sub(b.name, s, e)
    end
end

local stencilSprite, stencilX, stencilY = {}, 0, 0
local function stencil()
    if stencilSprite then
        love.graphics.push()
        love.graphics.translate(stencilX + stencilSprite.clipRect.x +
                                    stencilSprite.clipRect.width * 0.5,
                                stencilY + stencilSprite.clipRect.y +
                                    stencilSprite.clipRect.height * 0.5)
        love.graphics.rotate(stencilSprite.angle)
        love.graphics.translate(-stencilSprite.clipRect.width * 0.5,
                                -stencilSprite.clipRect.height * 0.5)
        love.graphics.rectangle("fill", -stencilSprite.width * 0.5,
                                -stencilSprite.height * 0.5,
                                stencilSprite.clipRect.width,
                                stencilSprite.clipRect.height)
        love.graphics.pop()
    end
end

local Sprite = Basic:extend()

function Sprite.newFrame(name, x, y, w, h, sw, sh, ox, oy, ow, oh)
    local aw, ah = x + w, y + h
    return {
        name = name,
        quad = love.graphics.newQuad(x, y, aw > sw and w - (aw - sw) or w,
                                     ah > sh and h - (ah - sh) or h, sw, sh),
        width = ow == nil and w or ow,
        height = oh == nil and h or oh,
        offset = {x = ox == nil and 0 or ox, y = oy == nil and 0 or oy}
    }
end

function Sprite.getFramesFromSparrow(texture, description)
    if type(texture) == "string" then
        texture = love.graphics.newImage(texture)
    end

    local frames = {texture = texture, frames = {}}
    local sw, sh = texture:getDimensions()
    for _, c in ipairs(parseXml(description).TextureAtlas.children) do
        if c.name == "SubTexture" then
            table.insert(frames.frames,
                         Sprite.newFrame(c.attrs.name, tonumber(c.attrs.x),
                                         tonumber(c.attrs.y),
                                         tonumber(c.attrs.width),
                                         tonumber(c.attrs.height), sw, sh,
                                         tonumber(c.attrs.frameX),
                                         tonumber(c.attrs.frameY),
                                         tonumber(c.attrs.frameWidth),
                                         tonumber(c.attrs.frameHeight)))
        end
    end

    return frames
end

function Sprite.getFramesFromPacker(texture, description)
    if type(texture) == "string" then
        texture = love.graphics.newImage(texture)
    end

    local frames = {texture = texture, frames = {}}
    local sw, sh = texture:getDimensions()

    local pack = description:trim()
    local lines = pack:split("\n")
    for i = 1, #lines do
        local currImageData = lines[i]:split("=")
        local name = currImageData[1]:trim()
        local currImageRegion = currImageData[2]:split(" ")

        table.insert(frames.frames,
                     Sprite.newFrame(name, tonumber(currImageRegion[1]),
                                     tonumber(currImageRegion[2]),
                                     tonumber(currImageRegion[3]),
                                     tonumber(currImageRegion[4]), sw, sh))
    end

    return frames
end

function Sprite.getTiles(texture, tileSize, region, tileSpacing)
    if region == nil then
        region = {
            x = 0,
            y = 0,
            width = texture:getWidth(),
            height = texture:getHeight()
        }
    else
        if region.width == 0 then
            region.width = texture:getWidth() - region.x
        end
        if region.height == 0 then
            region.height = texture:getHeight() - region.y
        end
    end

    tileSpacing = (tileSpacing ~= nil) and tileSpacing or {x = 0, y = 0}

    local tileFrames = {}

    region.x = math.floor(region.x)
    region.y = math.floor(region.y)
    region.width = math.floor(region.width)
    region.height = math.floor(region.height)
    tileSpacing = {x = math.floor(tileSpacing.x), y = math.floor(tileSpacing.y)}
    tileSize = {x = math.floor(tileSize.x), y = math.floor(tileSize.y)}

    local spacedWidth = tileSize.x + tileSpacing.x
    local spacedHeight = tileSize.y + tileSpacing.y

    local numRows = (tileSize.y == 0) and 1 or
                        math.floor(
                            (region.height + tileSpacing.y) / spacedHeight)
    local numCols = (tileSize.x == 0) and 1 or
                        math.floor((region.width + tileSpacing.x) / spacedWidth)

    local sw, sh = texture:getDimensions()
    local totalFrame = 0
    for j = 0, numRows - 1 do
        for i = 0, numCols - 1 do
            table.insert(tileFrames,
                         Sprite.newFrame(tostring(totalFrame),
                                         region.x + i * spacedWidth,
                                         region.y + j * spacedHeight,
                                         tileSize.x, tileSize.y, sw, sh))
            totalFrame = totalFrame + 1
        end
    end

    return tileFrames
end

local defaultTexture = love.graphics.newImage('art/default.png')

function Sprite:new(x, y, texture)
    Sprite.super.new(self)

    if x == nil then x = 0 end
    if y == nil then y = 0 end
    self.x = x
    self.y = y

    self.texture = defaultTexture
    self.width, self.height = 0, 0
    self.antialiasing = true

    self.origin = {x = 0, y = 0}
    self.offset = {x = 0, y = 0}
    self.scale = {x = 1, y = 1}
    self.scrollFactor = {x = 1, y = 1}
    self.clipRect = nil
    self.flipX = false
    self.flipY = false

    self.moves = false
    self.velocity = {x = 0, y = 0}
    self.acceleration = {x = 0, y = 0}

    self.color = {1, 1, 1}
    self.alpha = 1
    self.angle = 0

    self.shader = nil
    self.blend = "alpha"

    self.__frames = nil
    self.__animations = nil

    self.curAnim = nil
    self.curFrame = nil
    self.animFinished = nil
    self.animPaused = false

    self.__rectangleMode = false

    if texture then self:loadTexture(texture) end
end

function Sprite:loadTexture(texture, animated, frameWidth, frameHeight)
    if animated == nil then animated = false end

    if type(texture) == "string" then
        texture = love.graphics.newImage(texture) or defaultTexture
    end
    self.texture = texture

    self.__rectangleMode = false

    self.curAnim = nil
    self.curFrame = nil
    self.animFinished = nil

    if frameWidth == nil then frameWidth = 0 end
    if frameWidth == 0 then
        frameWidth = animated and self.texture:getHeight() or
                         self.texture:getWidth()
        frameWidth = (frameWidth > self.texture:getWidth()) or
                         self.texture:getWidth() or frameWidth
    elseif frameWidth > self.texture:getWidth() then
        print('frameWidth:' .. frameWidth ..
                  ' is larger than the graphic\'s width:' ..
                  self.texture:getWidth())
    end
    self.width = frameWidth

    if frameHeight == nil then frameHeight = 0 end
    if frameHeight == 0 then
        frameHeight = animated and frameWidth or self.texture:getHeight()
        frameHeight = (frameHeight > self.texture:getHeight()) or
                          self.texture:getHeight() or frameHeight
    elseif frameHeight > self.texture:getHeight() then
        print('frameHeight:' .. frameHeight ..
                  ' is larger than the graphic\'s height:' ..
                  self.texture:getHeight())
    end
    self.height = frameHeight

    if animated then
        self.__frames = Sprite.getTiles(texture,
                                        {x = frameWidth, y = frameHeight})
    end

    return self
end

function Sprite:make(width, height, color)
    if width == nil then width = 10 end
    if height == nil then height = 10 end
    if color == nil then color = {255, 255, 255} end

    self:setGraphicSize(width, height)
    self.color = color
    self.__rectangleMode = true
    self:updateHitbox()

    return self
end

function Sprite:setFrames(frames)
    self.__frames = frames.frames
    self.texture = frames.texture

    self:loadTexture(frames.texture)
    self.width, self.height = self:getFrameDimensions()
    self:centerOrigin()
end

function Sprite:getCurrentFrame()
    if self.curAnim then
        return self.curAnim.frames[math.floor(self.curFrame)]
    elseif self.__frames then
        return self.__frames[1]
    end
    return nil
end

function Sprite:getFrameWidth()
    local f = self:getCurrentFrame()
    if f then
        return f.width
    else
        return self.texture:getWidth()
    end
end

function Sprite:getFrameHeight()
    local f = self:getCurrentFrame()
    if f then
        return f.height
    else
        return self.texture:getHeight()
    end
end

function Sprite:getFrameDimensions()
    return self:getFrameWidth(), self:getFrameHeight()
end

function Sprite:setGraphicSize(width, height)
    if width == nil then width = 0 end
    if height == nil then height = 0 end

    self.scale = {
        x = width / self:getFrameWidth(),
        y = height / self:getFrameHeight()
    }

    if width <= 0 then
        self.scale.x = self.scale.y
    elseif height <= 0 then
        self.scale.y = self.scale.x
    end
end

function Sprite:updateHitbox()
    local w, h = self:getFrameDimensions()

    self.width = math.abs(self.scale.x) * w
    self.height = math.abs(self.scale.y) * h

    self.offset = {x = -0.5 * (self.width - w), y = -0.5 * (self.height - h)}
    self:centerOrigin()
end

function Sprite:centerOffsets()
    self.offset.x, self.offset.y = (self:getFrameWidth() - self.width) * 0.5,
                                   (self:getFrameHeight() - self.height) * 0.5
end

function Sprite:centerOrigin()
    self.origin.x, self.origin.y = self:getFrameWidth() * 0.5,
                                   self:getFrameHeight() * 0.5
end

function Sprite:setScrollFactor(x, y)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    self.scrollFactor.x, self.scrollFactor.y = x, y
end

function Sprite:getMidpoint()
    return self.x + self.width * 0.5, self.y + self.height * 0.5
end

function Sprite:getGraphicMidpoint()
    return self.x + self:getFrameWidth() * 0.5,
           self.y + self:getFrameHeight() * 0.5
end

function Sprite:setPosition(x, y)
    if x == nil then x = self.x end
    if y == nil then y = self.y end
    self.x, self.y = x, y
end

function Sprite:screenCenter(axes)
    if axes == nil then axes = "xy" end
    if axes:find("x") then self.x = (game.width - self.width) * 0.5 end
    if axes:find("y") then self.y = (game.height - self.height) * 0.5 end
    return self
end

function Sprite:addAnim(name, frames, framerate, looped)
    if framerate == nil then framerate = 30 end
    if looped == nil then looped = true end

    local anim = {
        name = name,
        framerate = framerate,
        looped = looped,
        frames = {}
    }
    for _, i in ipairs(frames) do
        table.insert(anim.frames, self.__frames[i + 1])
    end

    if not self.__animations then self.__animations = {} end
    self.__animations[name] = anim
end

function Sprite:addAnimByPrefix(name, prefix, framerate, looped)
    if framerate == nil then framerate = 30 end
    if looped == nil then looped = true end

    local anim = {
        name = name,
        framerate = framerate,
        looped = looped,
        frames = {}
    }
    for _, f in ipairs(self.__frames) do
        if f.name:startsWith(prefix) then table.insert(anim.frames, f) end
    end

    table.sort(anim.frames, sortFramesByIndices(prefix, ""))

    if not self.__animations then self.__animations = {} end
    self.__animations[name] = anim
end

function Sprite:addAnimByIndices(name, prefix, indices, postfix, framerate,
                                 looped)
    if postfix == nil then postfix = "" end
    if framerate == nil then framerate = 30 end
    if looped == nil then looped = true end

    local anim = {
        name = name,
        framerate = framerate,
        looped = looped,
        frames = {}
    }

    local allFrames = {}
    local notPostfix = #postfix <= 0
    for _, f in ipairs(self.__frames) do
        if f.name:startsWith(prefix) and
            (notPostfix or f.name:endsWith(postfix)) then
            table.insert(allFrames, f)
        end
    end
    table.sort(allFrames, sortFramesByIndices(prefix, postfix))

    for _, i in ipairs(indices) do
        local f = allFrames[i + 1]
        if f then table.insert(anim.frames, f) end
    end

    if not self.__animations then self.__animations = {} end
    self.__animations[name] = anim
end

function Sprite:play(anim, force, frame)
    if not force and self.curAnim and self.curAnim.name == anim and
        not self.animFinished then
        self.animFinished = false
        self.animPaused = false
        return
    end

    self.curAnim = self.__animations[anim]
    self.curFrame = frame or 1
    self.animFinished = false
    self.animPaused = false
end

function Sprite:pause()
    if self.curAnim and not self.animFinished then self.animPaused = true end
end

function Sprite:resume()
    if self.curAnim and not self.animFinished then self.animPaused = false end
end

function Sprite:stop()
    if self.curAnim then
        self.animFinished = true
        self.animPaused = true
    end
end

function Sprite:finish()
    if self.curAnim then
        self:stop()
        self.curFrame = #self.curAnim.frames
    end
end

function Sprite:destroy()
    Sprite.super.destroy(self)

    self.texture = nil

    self.origin.x, self.origin.y = 0, 0
    self.offset.x, self.offset.y = 0, 0
    self.scale.x, self.scale.y = 1, 1

    self.__frames = nil
    self.__animations = nil

    self.curAnim = nil
    self.curFrame = nil
    self.animFinished = nil
    self.animPaused = false
end

function Sprite:update(dt)
    if self.curAnim and not self.animFinished and not self.animPaused then
        self.curFrame = self.curFrame + dt * self.curAnim.framerate
        if self.curFrame >= #self.curAnim.frames then
            if self.curAnim.looped then
                self.curFrame = 1
            else
                self.curFrame = #self.curAnim.frames
                self.animFinished = true
            end
        end
    end

    if self.moves then
        self.velocity.x = self.velocity.x + self.acceleration.x * dt
        self.velocity.y = self.velocity.y + self.acceleration.y * dt

        self.x = self.x + self.velocity.x * dt
        self.y = self.y + self.velocity.y * dt
    end
end

function Sprite:draw()
    if self.alpha ~= 0 and (self.scale.x ~= 0 or self.scale.y ~= 0) then
        Sprite.super.draw(self)
    end
end

function Sprite:__render(camera)
    local min, mag, anisotropy = self.texture:getFilter()
    local mode = self.antialiasing and "linear" or "nearest"
    self.texture:setFilter(mode, mode, anisotropy)

    local f = self:getCurrentFrame()

    local shader = love.graphics.getShader()
    if self.shader then love.graphics.setShader(self.shader) end

    local blendMode, alphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode(self.blend)

    if self.clipRect then love.graphics.setStencilTest("greater", 0) end

    local x, y, rad, sx, sy, ox, oy = self.x, self.y, math.rad(self.angle),
                                      self.scale.x, self.scale.y, self.origin.x,
                                      self.origin.y

    if self.flipX then sx = -sx end
    if self.flipY then sy = -sy end

    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3],
                           self.alpha)

    x, y = x + ox - self.offset.x, y + oy - self.offset.y

    if f then ox, oy = ox + f.offset.x, oy + f.offset.y end

    x, y = x - (camera.scroll.x * self.scrollFactor.x),
           y - (camera.scroll.y * self.scrollFactor.y)

    if self.clipRect then
        stencilSprite, stencilX, stencilY = self, x, y
        love.graphics.stencil(stencil, "replace", 1, false)
    end

    if self.__rectangleMode then
        local w, h = self:getFrameDimensions()
        w, h = math.abs(self.scale.x) * w, math.abs(self.scale.y) * h

        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(rad)
        love.graphics.rectangle('fill', -w / 2, -h / 2, w, h)
        love.graphics.pop()
    elseif not f then
        love.graphics.draw(self.texture, x, y, rad, sx, sy, ox, oy)
    else
        love.graphics.draw(self.texture, f.quad, x, y, rad, sx, sy, ox, oy)
    end

    love.graphics.setColor(r, g, b, a)

    self.texture:setFilter(min, mag, anisotropy)
    if self.clipRect then love.graphics.setStencilTest() end
    if self.shader then love.graphics.setShader(shader) end
    love.graphics.setBlendMode(blendMode, alphaMode)
end

return Sprite
