local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local TimedClickBarClient = BaseComponent:Extend('TimedClickBarClient')

local DEFAULT_SPEED = 1.4
local DEFAULT_EDGE_SPEED_SCALE = 0.38
local DEFAULT_CENTER_SPEED_SCALE = 1.85

function TimedClickBarClient:Create(strikeLine: GuiObject, percentLabel: TextLabel?)
	self.StrikeLine = strikeLine
	self.PercentLabel = percentLabel
	self.Running = false
	self.Locked = false
	self.Position = 0
	self.Direction = 1
	self.FormatPercent = nil
	self._runConnections = {}
end

function TimedClickBarClient:SetPercent(percent: number)
	self.Position = math.clamp(percent, 0, 1)
	self.StrikeLine.Position = UDim2.fromScale(self.Position, self.StrikeLine.Position.Y.Scale)

	if self.PercentLabel then
		local displayPercent = if self.FormatPercent then self.FormatPercent(self.Position) else self.Position
		self.PercentLabel.Text = ('%d%%'):format(math.round(math.clamp(displayPercent, 0, 1) * 100))
	end
end

function TimedClickBarClient:DisconnectRun()
	for _, connection in ipairs(self._runConnections) do
		connection:Disconnect()
	end
	table.clear(self._runConnections)
end

function TimedClickBarClient:Lock(onLocked: (number) -> ())
	if self.Locked then
		return
	end

	self.Locked = true
	self.Running = false
	self:DisconnectRun()
	onLocked(self.Position)
end

function TimedClickBarClient:GetSpeedScale(config): number
	local edgeScale = tonumber(config and config.EdgeSpeedScale) or DEFAULT_EDGE_SPEED_SCALE
	local centerScale = tonumber(config and config.CenterSpeedScale) or DEFAULT_CENTER_SPEED_SCALE
	local centerWeight = math.sin(math.clamp(self.Position, 0, 1) * math.pi)
	return edgeScale + (centerScale - edgeScale) * centerWeight
end

function TimedClickBarClient:Play(config, onLocked: (number) -> ())
	self:DisconnectRun()
	self.Running = true
	self.Locked = false
	self.Direction = 1
	self.FormatPercent = if config and type(config.FormatPercent) == 'function' then config.FormatPercent else nil
	self:SetPercent(0)

	local speed = tonumber(config and config.Speed) or DEFAULT_SPEED

	table.insert(self._runConnections, RunService.RenderStepped:Connect(function(deltaTime)
		self.Position += speed * self:GetSpeedScale(config) * deltaTime * self.Direction
		if self.Position >= 1 then
			self:SetPercent(1)
			self.Direction = -1
		elseif self.Position <= 0 then
			self:SetPercent(0)
			self.Direction = 1
		else
			self:SetPercent(self.Position)
		end
	end))

	table.insert(self._runConnections, UserInputService.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		local keyCode = input.KeyCode

		if inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.Touch
			or keyCode == Enum.KeyCode.Space
			or keyCode == Enum.KeyCode.Return then
			self:Lock(onLocked)
		end
	end))
end

function TimedClickBarClient:CleanUp()
	self:DisconnectRun()
end

return TimedClickBarClient
