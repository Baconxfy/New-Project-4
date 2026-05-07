local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local PadClient = BaseComponent:Extend('PadClient')



local PRESS_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function PadClient:Create(padModel: Model)
	self.Model = padModel
	self.InteractPrompt = padModel:FindFirstChild('PadPrompt', true)
	self.PressureButton = padModel:FindFirstChild('Money Display', true)
	self._touchingCount = 0

	if not self.PressureButton or not self.PressureButton:IsA('BasePart') then
		return
	end

	self._restCFrame = self.PressureButton.CFrame
	self._pressedCFrame = self._restCFrame * CFrame.new(0, -math.clamp(self.PressureButton.Size.Y * 0.18, 0.08, 0.35), 0)

	self:AddConnection(self.PressureButton.Touched:Connect(function(part)
		if self:_IsLocalCharacterPart(part) then
			self._touchingCount += 1
			self:_TweenButton(self._pressedCFrame, PRESS_TWEEN)
		end
	end))

	self:AddConnection(self.PressureButton.TouchEnded:Connect(function(part)
		if self:_IsLocalCharacterPart(part) then
			self._touchingCount = math.max(0, self._touchingCount - 1)
			if self._touchingCount == 0 then
				self:_TweenButton(self._restCFrame, RELEASE_TWEEN)
			end
		end
	end))
	
	
end

function PadClient:_IsLocalCharacterPart(part: Instance): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and part:IsDescendantOf(character)
end

function PadClient:_TweenButton(cframe: CFrame, tweenInfo: TweenInfo)
	if self._tween then
		self._tween:Cancel()
	end

	self._tween = TweenService:Create(self.PressureButton, tweenInfo, { CFrame = cframe })
	self._tween:Play()
end

function PadClient:CleanUp()
	if self._tween then
		self._tween:Cancel()
	end
	if self.PressureButton and self._restCFrame then
		self.PressureButton.CFrame = self._restCFrame
	end
end

return PadClient
