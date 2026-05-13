local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)
local BrainrotBillboard = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('BrainrotBillboard'))

local BrainrotServer = BaseComponent:Extend('BrainrotServer')

local DEFAULT_MONEY_PER_SECOND = 1
local COLLECT_JUMP_HEIGHT = 1.25
local COLLECT_JUMP_UP_TIME = 0.14
local COLLECT_JUMP_DOWN_TIME = 0.22

local function getInventoryConfig(framework)
	return (framework and framework.Config and framework.Config.Inventory) or {}
end

local function getBrainrotConfig(framework)
	return (framework and framework.Config and framework.Config.Brainrot) or {}
end

local function prepPlacedModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('WeldConstraint') then
			descendant:Destroy()
		elseif descendant:IsA('BasePart') then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = false
		end
	end
end

function BrainrotServer:Create(model: Model, spawnPart: BasePart?)
	self.Model = model
	self.Name = model.Name
	self.Level = tonumber(model:GetAttribute('Level')) or 1
	local brainrotConfig = getBrainrotConfig(self.Framework)
	self.Config = (self.Framework.Config.Brainrots and self.Framework.Config.Brainrots[self.Name]) or {}
	self.MoneyPerSecond = tonumber(model:GetAttribute('MoneyPerSecond')) or tonumber(self.Config.MoneyPerSecond) or tonumber(self.Config.BaseIncome) or brainrotConfig.DefaultMoneyPerSecond or DEFAULT_MONEY_PER_SECOND
	self.UpgradeCount = tonumber(model:GetAttribute('UpgradeCount')) or 0
	self.SpawnPart = spawnPart

	model:SetAttribute(getInventoryConfig(self.Framework).ItemTypeAttribute or 'ItemType', 'Brainrot')
	model:SetAttribute('Rarity', model:GetAttribute('Rarity') or self.Config.Rarity or 'Common')
	model:SetAttribute('BaseIncome', tonumber(model:GetAttribute('BaseIncome')) or tonumber(self.Config.BaseIncome) or self.MoneyPerSecond)
	model:SetAttribute('Mutation', model:GetAttribute('Mutation') or self.Config.Mutation or 'Normal')
	model:SetAttribute('Level', self.Level)
	model:SetAttribute('MoneyPerSecond', self.MoneyPerSecond)
	model:SetAttribute('UpgradeCount', self.UpgradeCount)
	prepPlacedModel(model)
	BrainrotBillboard.Attach(model, self.Framework, {
		Name = self.Name,
		ModelName = self.Config.ModelName or self.Name,
		Rarity = model:GetAttribute('Rarity'),
		Mutation = model:GetAttribute('Mutation'),
		BaseIncome = self.MoneyPerSecond,
	})

	if self.SpawnPart then
		self:PivotToSpawn()
	end
end

function BrainrotServer:PivotToSpawn()
	if not self.Model or not self.SpawnPart then
		return
	end

	local pivot = self.Model:GetPivot()
	local boundingBoxCFrame, size = self.Model:GetBoundingBox()
	local pivotToBoundingBox = pivot:ToObjectSpace(boundingBoxCFrame)
	local targetBoundingBoxCFrame = self.SpawnPart.CFrame * CFrame.new(0, size.Y * 0.5, 0)
	self.Model:PivotTo(targetBoundingBoxCFrame * pivotToBoundingBox:Inverse())
	self.BaseCFrame = self.Model:GetPivot()
end

function BrainrotServer:PlayCollectJump()
	if not self.Model then
		return
	end

	if self._jumpValue then
		self._jumpValue:Destroy()
		self._jumpValue = nil
	end

	local baseCFrame = self.BaseCFrame or self.Model:GetPivot()
	local brainrotConfig = getBrainrotConfig(self.Framework)
	local jumpValue = Instance.new('CFrameValue')
	jumpValue.Value = baseCFrame
	self._jumpValue = jumpValue

	local connection = jumpValue:GetPropertyChangedSignal('Value'):Connect(function()
		if self._alive and self.Model then
			self.Model:PivotTo(jumpValue.Value)
		end
	end)

	local upTween = TweenService:Create(
		jumpValue,
		TweenInfo.new(brainrotConfig.CollectJumpUpTime or COLLECT_JUMP_UP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = baseCFrame * CFrame.new(0, brainrotConfig.CollectJumpHeight or COLLECT_JUMP_HEIGHT, 0) }
	)
	local downTween = TweenService:Create(
		jumpValue,
		TweenInfo.new(brainrotConfig.CollectJumpDownTime or COLLECT_JUMP_DOWN_TIME, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Value = baseCFrame }
	)

	task.spawn(function()
		upTween:Play()
		upTween.Completed:Wait()
		if self._alive then
			downTween:Play()
			downTween.Completed:Wait()
		end
		connection:Disconnect()
		if self._jumpValue == jumpValue then
			self._jumpValue = nil
		end
		jumpValue:Destroy()
	end)
end

function BrainrotServer:CleanUp()
	if self._jumpValue then
		self._jumpValue:Destroy()
		self._jumpValue = nil
	end
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
end

return BrainrotServer
