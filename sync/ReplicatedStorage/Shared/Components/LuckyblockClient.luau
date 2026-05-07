local ReplicatedStorage = game:GetService('ReplicatedStorage')
local InventoryItemClient = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('InventoryItemClient', true) :: ModuleScript)

local LuckyblockClient = InventoryItemClient:Extend('LuckyblockClient')

local MICROWAVE_PROMPT_NAME = 'MicrowavePrompt'

local equippedLuckyblockCount = 0
local promptWatcherBound = false

local function isMicrowavePrompt(instance: Instance): boolean
	return instance:IsA('ProximityPrompt') and instance.Name == MICROWAVE_PROMPT_NAME
end

local function setPromptEnabled(prompt: ProximityPrompt)
	prompt.Enabled = equippedLuckyblockCount > 0
end

local function refreshMicrowavePrompts()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if isMicrowavePrompt(descendant) then
			setPromptEnabled(descendant :: ProximityPrompt)
		end
	end
end

local function bindPromptWatcher()
	if promptWatcherBound then
		return
	end
	promptWatcherBound = true

	workspace.DescendantAdded:Connect(function(descendant)
		if isMicrowavePrompt(descendant) then
			setPromptEnabled(descendant :: ProximityPrompt)
		end
	end)
end

function LuckyblockClient:Create(model: Model)
	bindPromptWatcher()
	self:RefreshLuckyblock()
	refreshMicrowavePrompts()
end

function LuckyblockClient:SetModel(model: Model)
	InventoryItemClient.SetModel(self, model)
	self:RefreshLuckyblock()
end

function LuckyblockClient:SetEquipped(equipped: boolean)
	local wasEquipped = self.Equipped == true
	InventoryItemClient.SetEquipped(self, equipped)

	if wasEquipped == self.Equipped then
		return
	end

	equippedLuckyblockCount += if self.Equipped then 1 else -1
	equippedLuckyblockCount = math.max(equippedLuckyblockCount, 0)
	refreshMicrowavePrompts()
end

function LuckyblockClient:RefreshLuckyblock()
	self.LuckyblockName = self.Model.Name
end

function LuckyblockClient:CleanUp()
	if self.Equipped then
		equippedLuckyblockCount = math.max(equippedLuckyblockCount - 1, 0)
		refreshMicrowavePrompts()
	end
end

return LuckyblockClient
