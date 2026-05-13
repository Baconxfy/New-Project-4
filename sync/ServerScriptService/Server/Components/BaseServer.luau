local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local BaseServer = BaseComponent:Extend('BaseServer')

local function formatMoney(value: number): string
	value = math.max(0, math.floor(value))
	if value >= 1000000 then
		return ('$%.1fM'):format(value / 1000000):gsub('%.0M', 'M')
	elseif value >= 1000 then
		return ('$%.1fK'):format(value / 1000):gsub('%.0K', 'K')
	end
	return ('$%d'):format(value)
end

local function getPadIndex(padModel: Model, fallbackIndex: number): number
	local configuredIndex = padModel:GetAttribute('PadIndex')
	if type(configuredIndex) == 'number' then
		return configuredIndex
	end

	return tonumber(padModel.Name:match('%d+')) or fallbackIndex
end

local function getTextLabel(root: Instance?, name: string): TextLabel?
	if not root then
		return nil
	end

	local instance = root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextLabel') then instance else nil
end

local function getTextButton(root: Instance?, name: string): TextButton?
	if not root then
		return nil
	end

	local instance = root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextButton') then instance else nil
end

local function getStageTemplate(stageConfig)
	local assets = ReplicatedStorage:FindFirstChild('Assets')
	local bases = assets and assets:FindFirstChild('Bases')
	local templateName = stageConfig and stageConfig.TemplateName
	local template = templateName and bases and bases:FindFirstChild(templateName)
	return if template and template:IsA('Model') then template else nil
end

function BaseServer:Create(baseFolder:Folder)
	self.BaseFolder = baseFolder
	self.Owner = nil
	self.Pads = {}
	self.Fridges = {}
	self.Stage = nil
	self.StageModel = nil
	self:SetStage(self:GetDefaultStage(), self:GetDefaultEnabledCount(), true)
	self:SetPlayerNameText('Unclaimed')
end

function BaseServer:ClearStageComponents()
	for _, pad in ipairs(self.Pads) do
		pad:Destroy()
	end
	table.clear(self.Pads)

	for _, fridge in ipairs(self.Fridges) do
		fridge:Destroy()
	end
	table.clear(self.Fridges)

	self.PadUpgradeModel = nil
	self.PadUpgradeButton = nil
	self.PadUpgradePriceLabel = nil
	self.PadUpgradeSlotsLabel = nil
end

function BaseServer:GetCurrentStageModel(): Model?
	local stageModel = self.BaseFolder:FindFirstChild('WHOLE BASE')
	if stageModel and stageModel:IsA('Model') then
		return stageModel
	end

	for _, child in ipairs(self.BaseFolder:GetChildren()) do
		if child:IsA('Model') and (child:FindFirstChild('Pads', true) or child:FindFirstChild('PlayerName', true)) then
			return child
		end
	end

	return nil
end

function BaseServer:RebuildStageComponents()
	self:ClearStageComponents()

	self.StageModel = self:GetCurrentStageModel()
	local root = self.StageModel or self.BaseFolder
	self.SpawnLocation = root:FindFirstChildWhichIsA('SpawnLocation', true)

	local playerName = root:FindFirstChild('PlayerName', true)
	self.PlayerNameTextLabel = playerName and playerName:FindFirstChildWhichIsA('TextLabel', true) or nil
	self.PadUpgradeModel = root:FindFirstChild('PadUpgrade', true) or root:FindFirstChild('Pad Upgrade', true)
	self.PadUpgradeButton = getTextButton(self.PadUpgradeModel, 'Button')
	self.PadUpgradePriceLabel = getTextLabel(self.PadUpgradeModel, 'PriceTag')
	self.PadUpgradeSlotsLabel = getTextLabel(self.PadUpgradeModel, 'SlotsAmount')

	local padsFolder = root:FindFirstChild('Pads', true)
	if padsFolder then
		local padModels = {}
		for _, padModel in ipairs(padsFolder:GetChildren()) do
			if padModel:IsA('Model') then
				table.insert(padModels, padModel)
			end
		end

		table.sort(padModels, function(a, b)
			return getPadIndex(a, math.huge) < getPadIndex(b, math.huge)
		end)

		for fallbackIndex, padModel in ipairs(padModels) do
			table.insert(self.Pads, self.Framework.Components.PadServer:new(padModel, self, getPadIndex(padModel, fallbackIndex)))
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA('Model') and descendant.Name == 'Fridge' then
			table.insert(self.Fridges, self.Framework.Components.FridgeServer:new(descendant, self))
		end
	end
end

function BaseServer:GetBaseConfig()
	return (self.Framework.Config and self.Framework.Config.Base) or {}
end

function BaseServer:GetStageConfig(stage: number)
	local config = self:GetBaseConfig()
	return config.Stages and config.Stages[stage] or nil
end

function BaseServer:GetDefaultStage(): number
	return tonumber(self:GetBaseConfig().DefaultStage) or 1
end

function BaseServer:GetStagePadCount(stage: number): number
	local stageConfig = self:GetStageConfig(stage)
	return tonumber(stageConfig and stageConfig.Pads) or self:GetTotalPads()
end

function BaseServer:GetNextStage(stage: number): number?
	local nextStage = stage + 1
	return if self:GetStageConfig(nextStage) then nextStage else nil
end

function BaseServer:SetPlayerNameText(text: string)
	if self.PlayerNameTextLabel then
		self.PlayerNameTextLabel.Text = text
	end
end

function BaseServer:CapturePadContents()
	local contents = {}
	for _, pad in ipairs(self.Pads) do
		local content = pad:ExtractPlacedBrainrot()
		if content then
			content.PadIndex = pad.Index
			table.insert(contents, content)
		end
	end
	return contents
end

function BaseServer:ReturnPadContentToOwner(content)
	local model = content and content.Model
	if not model then
		return
	end

	if self.Owner then
		local cashToClaim = math.floor(tonumber(content.CashToClaim) or 0)
		if cashToClaim > 0 then
			self.Framework:GetService('DataService'):AddPlayerData(self.Owner.UserId, 'Cash', cashToClaim)
		end
		self.Framework:GetService('InventoryService'):AddItem(self.Owner, model, 'Brainrot', model.Name)
	end
	model:Destroy()
end

function BaseServer:RestorePadContents(contents)
	for _, content in ipairs(contents or {}) do
		local pad = self:GetPad(content.PadIndex)
		if not pad or not pad:RestorePlacedBrainrot(content.Model, content.CashToClaim) then
			self:ReturnPadContentToOwner(content)
		end
	end
end

function BaseServer:SetStage(stage: number, unlockedCount: number?, forceRebuild: boolean?)
	stage = math.max(1, math.floor(tonumber(stage) or self:GetDefaultStage()))
	if self.Stage == stage and forceRebuild ~= true then
		if unlockedCount ~= nil then
			self:ApplyPadUnlockCount(unlockedCount)
		end
		return true
	end

	local stageConfig = self:GetStageConfig(stage)
	if not stageConfig then
		return false
	end

	local template = getStageTemplate(stageConfig)
	if not template then
		return false
	end

	local padContents = self:CapturePadContents()
	local oldStageModel = self:GetCurrentStageModel()
	local pivot = oldStageModel and oldStageModel:GetPivot()
	self:ClearStageComponents()
	if oldStageModel then
		oldStageModel:Destroy()
	end

	local newStageModel = template:Clone()
	newStageModel.Name = 'WHOLE BASE'
	newStageModel.Parent = self.BaseFolder
	if pivot then
		newStageModel:PivotTo(pivot)
	end

	self.Stage = stage
	self:RebuildStageComponents()
	if unlockedCount ~= nil then
		self:ApplyPadUnlockCount(unlockedCount)
	end
	self:RestorePadContents(padContents)
	if self.Owner then
		self:SetPlayerNameText(self.Owner.DisplayName .. "'s Base")
	else
		self:SetPlayerNameText('Unclaimed')
	end
	return true
end

function BaseServer:Claim(player:Player)
	if self.Owner ~= nil then return end
	self.Owner = player
	local baseService = self.Framework:GetService('BaseService')
	local stage = baseService:GetPlayerStage(player)
	local unlockedCount = baseService:GetUnlockedPadCount(player)
	self:SetStage(stage, unlockedCount)
	self:UpdatePadUpgradeDisplay(baseService:GetPadUpgradeState(player))
	self.Framework:GetController('BaseController').Server.Fire:ClaimBase(player, self.BaseFolder)
	self:SetPlayerNameText(player.DisplayName .. "'s Base")
end

function BaseServer:Unclaim()
	self.Owner = nil
	self:SetStage(self:GetDefaultStage(), self:GetDefaultEnabledCount(), true)
	self:SetPlayerNameText('Unclaimed')
	self:UpdatePadUpgradeDisplay(nil)
	for _, pad in ipairs(self.Pads) do
		pad:Reset()
	end
	for _, fridge in ipairs(self.Fridges) do
		fridge:Reset()
	end
end

function BaseServer:GetPad(index: number)
	for _, pad in ipairs(self.Pads) do
		if pad.Index == index then
			return pad
		end
	end
	return nil
end

function BaseServer:SetPadEnabled(index: number, enabled: boolean)
	local pad = self:GetPad(index)
	if not pad then
		return false
	end

	pad:SetEnabled(enabled)
	return true
end

function BaseServer:GetDefaultEnabledCount(): number
	local config = (self.Framework.Config and self.Framework.Config.Pads) or {}
	return tonumber(config.DefaultEnabledCount) or 1
end

function BaseServer:GetTotalPads(): number
	return #self.Pads
end

function BaseServer:ApplyPadUnlockCount(unlockedCount: number)
	local count = math.clamp(math.floor(tonumber(unlockedCount) or self:GetDefaultEnabledCount()), 0, self:GetTotalPads())
	for _, pad in ipairs(self.Pads) do
		pad:SetEnabled(pad.Index <= count)
	end
	return count
end

function BaseServer:UpdatePadUpgradeDisplay(state)
	if self.PadUpgradeSlotsLabel then
		self.PadUpgradeSlotsLabel.Text = if state and not state.Maxed and state.NextPadIndex then ('Slot #%d'):format(state.NextPadIndex) else ''
	end

	if self.PadUpgradePriceLabel then
		self.PadUpgradePriceLabel.Text = if state and not state.Maxed and state.NextPrice then formatMoney(state.NextPrice) else ''
	end

	if self.PadUpgradeButton then
		self.PadUpgradeButton.Visible = state == nil or state.Maxed ~= true
		self.PadUpgradeButton.Active = state == nil or state.Maxed ~= true
		pcall(function()
			(self.PadUpgradeButton :: any).Interactable = state == nil or state.Maxed ~= true
		end)
		self.PadUpgradeButton.AutoButtonColor = false
	end
end

return BaseServer
