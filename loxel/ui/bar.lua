---@class Bar:Object
local Bar = Object:extend("Bar")

function Bar:new(x, y, width, height, maxValue, color, filledBar, opColor)
	Bar.super.new(self, x, y)

	self.width = width or 100
	self.height = height or 20

	self.maxValue = maxValue or 100
	self.value = self.maxValue

	self.color = color or {1, 0, 0}
	self.opColor = opColor or {0, 1, 0}

	self.filledBar = filledBar or false
	self.fillWidth = self.width - ((self.value / self.maxValue) * self.width)
	self.percent = (self.value / self.maxValue) * 100
end

function Bar:setValue(value)
	self.value = math.min(math.max(value, 0), self.maxValue)
end

function Bar:update()
	self.fillWidth = self.width - ((self.value / self.maxValue) * self.width)
	self.percent = (self.value / self.maxValue) * 100
end

function Bar:__render(camera)
	local r, g, b, a = love.graphics.getColor()

	if self.filledBar then
		local color = self.flipX and self.color or self.opColor
		love.graphics.setColor(color[1], color[2], color[3], self.alpha)
		love.graphics.rectangle("fill", self.x + self.fillWidth, self.y,
								self.width - self.fillWidth, self.height)
	end

	local color = self.flipX and self.opColor or self.color
	love.graphics.setColor(color[1], color[2], color[3], self.alpha)
	love.graphics.rectangle("fill", self.x, self.y, self.fillWidth, self.height)

	love.graphics.setColor(r, g, b, a)
end

return Bar
