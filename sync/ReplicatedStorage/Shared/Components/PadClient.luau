local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local PadClient = BaseComponent:Extend('PadClient')

local PRESS_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PAD_ENABLED_ATTRIBUTE = 'PadEnabled'
local PAD_OCCUPIED_ATTRIBUTE = 'PadOccupied'
local PLACE_ACTION_TEXT = 'Place'
local REPLACE_ACTION_TEXT = 'Replace'
local PICKUP_ACTION_TEXT = 'Pick Up'

local function getPadEnabledAttribute(framework): string
	return (framework and framework.Config and framework.Config.Pads and framework.Config.Pads.EnabledAttribute)
		or PAD_ENABLED_ATTRIBUTE
end

function PadClient:Create(padModel: Model)
	self.Model = padModel
	self.InteractPrompt = padModel:FindFirstChild('PadPrompt', true)
	self.PressureButton = padModel:FindFirstChild('Money Display', true)
	self._touchingCount = 0
	self:BindPrompt()

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

function PadClient:BindPrompt()
	if not self.InteractPrompt or not self.InteractPrompt:IsA('ProximityPrompt') then
		return
	end

	local enabledAttribute = getPadEnabledAttribute(self.Framework)
	self:AddConnection(self.Model:GetAttributeChangedSignal(enabledAttribute):Connect(function()
		self:RefreshPrompt()
	end))
	self:AddConnection(self.Model:GetAttributeChangedSignal(PAD_OCCUPIED_ATTRIBUTE):Connect(function()
		self:RefreshPrompt()
	end))
	self:AddConnection(self.InteractPrompt:GetAttributeChangedSignal(enabledAttribute):Connect(function()
		self:RefreshPrompt()
	end))
	self:AddConnection(self.InteractPrompt:GetAttributeChangedSignal(PAD_OCCUPIED_ATTRIBUTE):Connect(function()
		self:RefreshPrompt()
	end))

	local inventoryController = self.Framework:GetController('InventoryController')
	if inventoryController and inventoryController.Changed then
		self:AddConnection(inventoryController.Changed.Event:Connect(function()
			self:RefreshPrompt()
		end))
	end

	self:RefreshPrompt()
end

function PadClient:HasEquippedBrainrot(): boolean
	local inventoryController = self.Framework:GetController('InventoryController')
	local equippedItem = inventoryController and inventoryController:GetEquippedItem()
	return equippedItem ~= nil and equippedItem.ItemType == 'Brainrot'
end

function PadClient:IsPadEnabled(): boolean
	local enabledAttribute = getPadEnabledAttribute(self.Framework)
	local padEnabled = self.InteractPrompt and self.InteractPrompt:GetAttribute(enabledAttribute)
	if type(padEnabled) ~= 'boolean' then
		padEnabled = self.Model:GetAttribute(enabledAttribute)
	end
	return padEnabled ~= false
end

function PadClient:IsOccupied(): boolean
	local occupied = self.InteractPrompt and self.InteractPrompt:GetAttribute(PAD_OCCUPIED_ATTRIBUTE)
	if type(occupied) ~= 'boolean' then
		occupied = self.Model:GetAttribute(PAD_OCCUPIED_ATTRIBUTE)
	end
	return occupied == true
end

function PadClient:RefreshPrompt()
	if not self.InteractPrompt or not self.InteractPrompt:IsA('ProximityPrompt') then
		return
	end

	local occupied = self:IsOccupied()
	local hasEquippedBrainrot = self:HasEquippedBrainrot()
	if occupied then
		self.InteractPrompt.ActionText = if hasEquippedBrainrot then REPLACE_ACTION_TEXT else PICKUP_ACTION_TEXT
	else
		self.InteractPrompt.ActionText = PLACE_ACTION_TEXT
	end
	self.InteractPrompt.Enabled = self:IsPadEnabled() and (occupied or hasEquippedBrainrot)
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
