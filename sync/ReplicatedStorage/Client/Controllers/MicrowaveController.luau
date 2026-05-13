local ProximityPromptService = game:GetService('ProximityPromptService')
local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local MicrowaveController = Framework:CreateController('MicrowaveController')

local DEFAULT_MICROWAVE_PROMPT_NAME = 'MicrowavePrompt'
local DEFAULT_SET_POWER_GUI_NAME = 'SetPower'
local DEFAULT_STOP_MICROWAVE_GUI_NAME = 'StopMicrowave'
local DEFAULT_ITEM_TYPE_ATTRIBUTE = 'ItemType'

local function getMicrowaveConfig()
	return (Framework.Config and Framework.Config.Microwave) or {}
end

function MicrowaveController:Initialize()
	self.SetPowerRequested = Instance.new('BindableEvent')
	self.ActiveClient = nil
	self.SetPowerGui = nil
	self.SetPowerUi = nil
	self.StopMicrowaveGui = nil
	self.StopMicrowaveUi = nil
	self.MicrowavePrompts = {}
	self.PendingMicrowaveStart = false
end

function MicrowaveController:Start()
	self.MicrowaveService = Framework:GetService('MicrowaveService')
	self:BindSetPowerUi()
	self:BindStopMicrowaveUi()
	self:BindPromptRefresh()

	self:AddConnection(self.SetPowerRequested.Event:Connect(function(session)
		self:StartMinigame(session)
	end))
	self:AddConnection(ProximityPromptService.PromptTriggered:Connect(function(prompt)
		self:HandlePromptTriggered(prompt)
	end))
	task.defer(function()
		if self._alive then
			self:RefreshMicrowavePrompts()
		end
	end)
end

function MicrowaveController:BindSetPowerUi()
	if self.SetPowerUi then
		return
	end

	local playerGui = self.Framework.Players.LocalPlayer:WaitForChild('PlayerGui')
	self.SetPowerGui = self.SetPowerGui and self.SetPowerGui.Parent and self.SetPowerGui or playerGui:FindFirstChild(getMicrowaveConfig().SetPowerGuiName or DEFAULT_SET_POWER_GUI_NAME)
	if self.SetPowerGui then
		self.SetPowerUi = Framework.Components.SetPowerUiClient:new(self.SetPowerGui)
		self:AddChild(self.SetPowerUi)
	end
end

function MicrowaveController:BindStopMicrowaveUi()
	if self.StopMicrowaveUi then
		return
	end

	local playerGui = self.Framework.Players.LocalPlayer:WaitForChild('PlayerGui')
	self.StopMicrowaveGui = self.StopMicrowaveGui and self.StopMicrowaveGui.Parent and self.StopMicrowaveGui or playerGui:FindFirstChild(getMicrowaveConfig().StopMicrowaveGuiName or DEFAULT_STOP_MICROWAVE_GUI_NAME)
	if self.StopMicrowaveGui then
		self.StopMicrowaveUi = Framework.Components.StopMicrowaveUiClient:new(self.StopMicrowaveGui)
		self:AddChild(self.StopMicrowaveUi)
	end
end

function MicrowaveController:SetInventoryEnabled(enabled: boolean)
	local inventoryController = Framework:GetController('InventoryController')
	if inventoryController and inventoryController.SetActionsEnabled then
		inventoryController:SetActionsEnabled(enabled)
	elseif inventoryController and inventoryController.SetKeybindsEnabled then
		inventoryController:SetKeybindsEnabled(enabled)
	end
end

function MicrowaveController:BindPromptRefresh()
	if self._promptRefreshBound then
		return
	end
	self._promptRefreshBound = true
	self:ScanMicrowavePrompts()
	self:AddConnection(workspace.DescendantAdded:Connect(function(descendant)
		local promptName = getMicrowaveConfig().PromptName or DEFAULT_MICROWAVE_PROMPT_NAME
		if descendant:IsA('ProximityPrompt') and descendant.Name == promptName then
			self:TrackMicrowavePrompt(descendant)
		end
	end))

	local inventoryController = Framework:GetController('InventoryController')
	if inventoryController and inventoryController.Changed then
		self:AddConnection(inventoryController.Changed.Event:Connect(function()
			self:RefreshMicrowavePrompts()
		end))
	end

	local player = self.Framework.Players.LocalPlayer
	local function bindCharacter(character: Model?)
		if self._characterPromptConnections then
			for _, connection in ipairs(self._characterPromptConnections) do
				connection:Disconnect()
			end
		end
		self._characterPromptConnections = {}
		if not character then
			self:RefreshMicrowavePrompts()
			return
		end

		table.insert(self._characterPromptConnections, character.ChildAdded:Connect(function(child)
			if child:IsA('Model') then
				self:RefreshMicrowavePrompts()
			end
		end))
		table.insert(self._characterPromptConnections, character.ChildRemoved:Connect(function(child)
			if child:IsA('Model') then
				self:RefreshMicrowavePrompts()
			end
		end))
		self:RefreshMicrowavePrompts()
	end

	self:AddConnection(player.CharacterAdded:Connect(bindCharacter))
	bindCharacter(player.Character)
end

function MicrowaveController:TrackMicrowavePrompt(prompt: ProximityPrompt)
	for _, existing in ipairs(self.MicrowavePrompts) do
		if existing == prompt then
			self:RefreshMicrowavePrompts()
			return
		end
	end

	table.insert(self.MicrowavePrompts, prompt)
	self:RefreshMicrowavePrompts()
end

function MicrowaveController:ScanMicrowavePrompts()
	local promptName = getMicrowaveConfig().PromptName or DEFAULT_MICROWAVE_PROMPT_NAME
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA('ProximityPrompt') and descendant.Name == promptName then
			self:TrackMicrowavePrompt(descendant)
		end
	end
end

function MicrowaveController:HasEquippedLuckyblock(): boolean
	local inventoryController = Framework:GetController('InventoryController')
	if inventoryController and inventoryController.ActionsEnabled == false then
		return false
	end

	local equippedItem = inventoryController and inventoryController:GetEquippedItem()
	if equippedItem and equippedItem.ItemType == 'Luckyblock' then
		return true
	end

	local player = self.Framework.Players.LocalPlayer
	local character = player and player.Character
	local inventoryConfig = (Framework.Config and Framework.Config.Inventory) or {}
	local itemTypeAttribute = inventoryConfig.ItemTypeAttribute or DEFAULT_ITEM_TYPE_ATTRIBUTE
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA('Model') and child:GetAttribute(itemTypeAttribute) == 'Luckyblock' then
			return true
		end
	end
	return false
end

function MicrowaveController:RefreshMicrowavePrompts()
	local enabled = not self.PendingMicrowaveStart and self.ActiveClient == nil and self:HasEquippedLuckyblock()
	for index = #self.MicrowavePrompts, 1, -1 do
		local prompt = self.MicrowavePrompts[index]
		if not prompt.Parent then
			table.remove(self.MicrowavePrompts, index)
		else
			prompt.Enabled = enabled
		end
	end
end

function MicrowaveController:ClearActiveClient(restoreInventory: boolean?)
	if self.ActiveClient then
		local activeClient = self.ActiveClient
		self.ActiveClient = nil
		pcall(function()
			activeClient:Destroy()
		end)
	end
	self.PendingMicrowaveStart = false
	if restoreInventory ~= false then
		self:SetInventoryEnabled(true)
	end
	self:RefreshMicrowavePrompts()
end

function MicrowaveController:HandlePromptTriggered(prompt: ProximityPrompt)
	if prompt.Name ~= (getMicrowaveConfig().PromptName or DEFAULT_MICROWAVE_PROMPT_NAME) then
		return
	end

	if self.ActiveClient ~= nil then
		return
	end

	if not self:HasEquippedLuckyblock() then
		return
	end

	self.PendingMicrowaveStart = true
	self:SetInventoryEnabled(false)
	self:RefreshMicrowavePrompts()

	task.delay(4, function()
		if self._alive and self.PendingMicrowaveStart and self.ActiveClient == nil then
			self.PendingMicrowaveStart = false
			self:SetInventoryEnabled(true)
			self:RefreshMicrowavePrompts()
		end
	end)
end

function MicrowaveController:StartMinigame(session)
	self.PendingMicrowaveStart = false
	self:BindSetPowerUi()
	self:BindStopMicrowaveUi()
	if not self.SetPowerUi or not self.StopMicrowaveUi then
		warn('[MicrowaveController] Missing microwave timing UI')
		self.MicrowaveService:FinishMicrowave()
		self:ClearActiveClient()
		return
	end

	self:ClearActiveClient(false)
	self:SetInventoryEnabled(false)
	self:RefreshMicrowavePrompts()
	self.ActiveClient = Framework.Components.MicrowaveClient:new(
		session,
		self.MicrowaveService,
		self.SetPowerUi,
		self.StopMicrowaveUi,
		function()
			self.ActiveClient = nil
			self:SetInventoryEnabled(true)
			self:RefreshMicrowavePrompts()
		end
	)
	self:AddChild(self.ActiveClient)
	local ok, err = pcall(function()
		self.ActiveClient:Play()
	end)
	if not ok then
		warn(('[MicrowaveController] Microwave client failed: %s'):format(tostring(err)))
		self.MicrowaveService:FinishMicrowave()
		self:ClearActiveClient()
	end
end

function MicrowaveController.Server:ShowSetPower(session)
	self.SetPowerRequested:Fire(session)
end

return MicrowaveController
