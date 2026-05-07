local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local FridgeServer = BaseComponent:Extend('FridgeServer')

local LUCKYBLOCK_MODELS = ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Luckyblocks')
local CLICK_COOLDOWN = 0.08
local XP_PER_PUMP = 10
local MIN_BLOCK_SCALE = 0.35
local MAX_BLOCK_SCALE = 1

local function getBlockOrder(config)
	local order = {}
	for name, blockConfig in pairs(config) do
		if type(blockConfig) == 'table' and tonumber(blockConfig.XpRequired) then
			table.insert(order, name)
		end
	end
	table.sort(order, function(a, b)
		local aRequired = tonumber(config[a].XpRequired) or math.huge
		local bRequired = tonumber(config[b].XpRequired) or math.huge
		if aRequired == bRequired then
			return a < b
		end
		return aRequired < bRequired
	end)
	return order
end

local function findDescendantByName(root: Instance, name: string): Instance?
	local wanted = string.lower(name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if string.lower(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

function FridgeServer:Create(fridgeModel: Model, baseServer: any?)
	self.Model = fridgeModel
	self.Base = baseServer
	self.Button = fridgeModel:FindFirstChild('Button', true)
	self.TakePrompt = fridgeModel:FindFirstChild('TakePrompt', true)
	self.SpawnPart = findDescendantByName(fridgeModel, 'BlockSpawnPos')
	self.Config = self.Framework.Config.Luckyblocks or {}
	self.BlockOrder = getBlockOrder(self.Config)
	self.BlockIndex = nil
	self.TotalXP = 0
	self.CurrentBlock = nil
	self.LastPumpAt = 0
	self.XPPerPump = XP_PER_PUMP
	self.MinScale = MIN_BLOCK_SCALE
	self.MaxScale = MAX_BLOCK_SCALE

	if not self.Button or not self.Button:IsA('BasePart') then
		warn(('[FridgeServer] %s is missing a Button part'):format(fridgeModel:GetFullName()))
		return
	end

	if not self.SpawnPart or not self.SpawnPart:IsA('BasePart') then
		warn(('[FridgeServer] %s is missing BlockSpawnPos'):format(fridgeModel:GetFullName()))
		return
	end

	self.ButtonRestCFrame = self.Button.CFrame
	self.BlockFolder = fridgeModel:FindFirstChild('GeneratedLuckyblocks') or Instance.new('Folder')
	self.BlockFolder.Name = 'GeneratedLuckyblocks'
	self.BlockFolder.Parent = fridgeModel
	self.BlockFolder:ClearAllChildren()

	self.ClickDetector = self.Button:FindFirstChildWhichIsA('ClickDetector') or Instance.new('ClickDetector')
	self.ClickDetector.MaxActivationDistance = 14
	self.ClickDetector.Parent = self.Button

	self:AddConnection(self.ClickDetector.MouseClick:Connect(function(player)
		self:Pump(player)
	end))

	if self.TakePrompt and self.TakePrompt:IsA('ProximityPrompt') then
		self.TakePrompt.Enabled = false
		self:AddConnection(self.TakePrompt.Triggered:Connect(function(player)
			self:Take(player)
		end))
	else
		warn(('[FridgeServer] %s is missing TakePrompt'):format(fridgeModel:GetFullName()))
	end
end

function FridgeServer:GetBlockName(index: number?): string?
	local blockIndex = index or self.BlockIndex
	return blockIndex and self.BlockOrder[blockIndex] or nil
end

function FridgeServer:GetBlockConfig(index: number?)
	local blockName = self:GetBlockName(index)
	return blockName and self.Config[blockName] or nil
end

function FridgeServer:GetRequiredXP(index: number): number
	local config = self:GetBlockConfig(index)
	return tonumber(config and config.XpRequired) or math.huge
end

function FridgeServer:IsOwner(player: Player): boolean
	return not self.Base or self.Base.Owner == player
end

function FridgeServer:GetBlockIndexForXP(xp: number): number?
	local bestIndex = nil
	for index in ipairs(self.BlockOrder) do
		if xp >= self:GetRequiredXP(index) then
			bestIndex = index
		else
			break
		end
	end
	return bestIndex
end

function FridgeServer:GetBlockProgress(index: number): number
	local currentRequired = self:GetRequiredXP(index)
	local nextRequired = self:GetRequiredXP(index + 1)

	if nextRequired == math.huge then
		return 0
	end

	local range = nextRequired - currentRequired
	if range <= 0 then
		return 1
	end

	return (self.TotalXP - currentRequired) / range
end

function FridgeServer:SpawnBlock(index: number)
	local blockName = self:GetBlockName(index)
	local template = blockName and LUCKYBLOCK_MODELS:FindFirstChild(blockName)

	if not template or not template:IsA('Model') then
		warn(('[FridgeServer] Missing luckyblock model for %s'):format(tostring(blockName)))
		return
	end

	if self.CurrentBlock then
		self.CurrentBlock:Destroy()
	end

	self.BlockIndex = index
	self.CurrentBlock = self.Framework.Components.LuckyblockServer:new(
		template,
		blockName,
		self.BlockFolder,
		self.SpawnPart,
		self.MinScale,
		self.MaxScale
	)
end

function FridgeServer:RefreshBlock()
	local index = self:GetBlockIndexForXP(self.TotalXP)
	if not index then
		return
	end

	if self.BlockIndex ~= index or not self.CurrentBlock then
		self:SpawnBlock(index)
	end

	if self.CurrentBlock then
		self.CurrentBlock:SetProgress(self:GetBlockProgress(index))
	end

	if self.TakePrompt and self.TakePrompt:IsA('ProximityPrompt') then
		self.TakePrompt.Enabled = self.CurrentBlock ~= nil
	end
end

function FridgeServer:PlayPumpFeedback()
	local downCFrame = self.ButtonRestCFrame * CFrame.new(0, -0.12, 0)
	TweenService:Create(self.Button, TweenInfo.new(0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = downCFrame }):Play()
	task.delay(0.05, function()
		if self._alive and self.Button then
			TweenService:Create(self.Button, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = self.ButtonRestCFrame }):Play()
		end
	end)
end

function FridgeServer:Pump(player: Player)
	if player and not self:IsOwner(player) then
		return
	end

	local now = os.clock()
	if now - self.LastPumpAt < CLICK_COOLDOWN then
		return
	end
	self.LastPumpAt = now

	self.TotalXP += self.XPPerPump
	self:RefreshBlock()
	self:PlayPumpFeedback()
end

function FridgeServer:Take(player: Player)
	if not player or not self:IsOwner(player) or not self.CurrentBlock then
		return
	end

	local blockName = self:GetBlockName()
	local blockModel = self.CurrentBlock.Model
	if not blockName or not blockModel then
		return
	end

	local inventoryService = self.Framework:GetService('InventoryService')
	inventoryService:AddLuckyblock(player, blockModel, blockName)
	self:Reset()
end

function FridgeServer:Reset()
	self.BlockIndex = nil
	self.TotalXP = 0
	if self.CurrentBlock then
		self.CurrentBlock:Destroy()
		self.CurrentBlock = nil
	end
	self.BlockFolder:ClearAllChildren()
	if self.TakePrompt and self.TakePrompt:IsA('ProximityPrompt') then
		self.TakePrompt.Enabled = false
	end
end

function FridgeServer:CleanUp()
	if self.CurrentBlock then
		self.CurrentBlock:Destroy()
		self.CurrentBlock = nil
	end
end

return FridgeServer
