local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local InventoryController = Framework:CreateController('InventoryController')

local InventoryItemClient = Framework.Components.InventoryItemClient
local componentClassCache = {}
local INVENTORY_SLOT_ATTRIBUTE = 'InventorySlot'
local INVENTORY_MODEL_ID_ATTRIBUTE = 'InventoryModelId'

local SLOT_KEYCODES = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
	[Enum.KeyCode.KeypadZero] = 10,
}

local function isInventoryCandidate(instance: Instance): boolean
	return instance:IsA('Model')
end

function InventoryController:Initialize()
	self.Player = Players.LocalPlayer
	self.Backpack = nil
	self.InventoryGui = nil
	self.InventoryUi = nil
	self.Items = {}
	self.ItemsBySlot = {}
	self.SelectedSlot = nil
	self.EquippedSlot = nil
	self.KeybindsEnabled = true
	self.ActionsEnabled = true
	self.Changed = Instance.new('BindableEvent')
	self.BackpackToggleRequested = Instance.new('BindableEvent')
	self.ItemComponents = {}
	self._connections = {}
	self._snapshotRequestId = 0
	self._snapshotApplyId = 0
	self._inventoryActionActive = false
	self._queuedInventorySlot = nil
	self._queuedInventoryToSlot = nil
	self._queuedInventoryMode = nil
	self._suppressModelSnapshotsUntil = 0
end

function InventoryController:Start()
	self.InventoryService = Framework:GetService('InventoryService')
	self.Backpack = self.Player:WaitForChild('Backpack')
	self:BindBackpack(self.Backpack)
	self:BindCharacter(self.Player.Character)
	self:AddConnection(self.Player.CharacterAdded:Connect(function(character)
		self:BindCharacter(character)
		self:RequestInitialSnapshot()
	end))
	self:BindKeybinds()
	self:BindInventoryGui()
	self:RequestInitialSnapshot()
end

function InventoryController:BindInventoryGui()
	if self.InventoryUi then
		return
	end

	local playerGui = self.Player:WaitForChild('PlayerGui')
	self.InventoryGui = self.InventoryGui and self.InventoryGui.Parent and self.InventoryGui or playerGui:WaitForChild('InventoryGui', 10)
	if self.InventoryGui then
		self.InventoryUi = Framework.Components.InventoryGuiClient:new(self.InventoryGui, self)
		self:AddChild(self.InventoryUi)
	else
		warn('[InventoryController] Missing InventoryGui')
	end
end

function InventoryController:BindBackpack(backpack: Backpack)
	self:DisconnectConnections(self._connections)

	table.insert(self._connections, backpack.ChildAdded:Connect(function(child)
		if isInventoryCandidate(child) and not self:ShouldSuppressModelSnapshot() then
			self:RequestSnapshotSoon()
		end
	end))

	table.insert(self._connections, backpack.ChildRemoved:Connect(function(child)
		if isInventoryCandidate(child) and not self:ShouldSuppressModelSnapshot() then
			self:RequestSnapshotSoon()
		end
	end))
end

function InventoryController:BindCharacter(character: Model?)
	self:DisconnectConnections(self._characterConnections)
	self._characterConnections = {}
	if not character then
		return
	end

	table.insert(self._characterConnections, character.ChildAdded:Connect(function(child)
		if isInventoryCandidate(child) and not self:ShouldSuppressModelSnapshot() then
			self:RequestSnapshotSoon()
		end
	end))

	table.insert(self._characterConnections, character.ChildRemoved:Connect(function(child)
		if isInventoryCandidate(child) and not self:ShouldSuppressModelSnapshot() then
			self:RequestSnapshotSoon()
		end
	end))
end

function InventoryController:DisconnectConnections(connections)
	if not connections then
		return
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

function InventoryController:BindKeybinds()
	if self._inputConnection then
		self._inputConnection:Disconnect()
	end

	self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		self:HandleInputBegan(input, gameProcessed)
	end)
end

function InventoryController:ShouldSuppressModelSnapshot(): boolean
	return os.clock() < (self._suppressModelSnapshotsUntil or 0)
end

function InventoryController:SetKeybindsEnabled(enabled: boolean)
	self.KeybindsEnabled = enabled == true
end

function InventoryController:SetActionsEnabled(enabled: boolean)
	self.ActionsEnabled = enabled == true
	self:SetKeybindsEnabled(enabled)

	if self.ActionsEnabled then
		self:RequestSnapshotSoon()
		return
	end

	self._queuedInventoryMode = nil
	self._queuedInventorySlot = nil
	self._queuedInventoryToSlot = nil
	self._suppressModelSnapshotsUntil = os.clock() + 0.35
	self:ApplyOptimisticEquip(nil)
end

function InventoryController:HandleInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not self.KeybindsEnabled then
		return
	end

	local slot = SLOT_KEYCODES[input.KeyCode]
	if slot then
		self:ToggleSlot(slot)
		return
	end

	if input.KeyCode == Enum.KeyCode.Backspace then
		self:UnequipItem()
		return
	end

	if input.KeyCode == Enum.KeyCode.Backquote then
		self.BackpackToggleRequested:Fire()
	end
end

function InventoryController:RequestInitialSnapshot()
	local snapshot = self.InventoryService:GetItems()
	self:ApplySnapshot(snapshot)
end

function InventoryController:RequestSnapshotSoon()
	self._snapshotRequestId += 1
	local requestId = self._snapshotRequestId
	task.delay(0.08, function()
		if self._snapshotRequestId == requestId then
			self:RequestInitialSnapshot()
		end
	end)
end

function InventoryController:ApplySnapshot(snapshot, retryCount: number?)
	self._snapshotApplyId += 1
	local applyId = self._snapshotApplyId
	local items = {}
	local modelLookup = self:GetInventoryModelLookup(snapshot or {})
	local missingModel = false

	for _, item in ipairs(snapshot or {}) do
		local copy = table.clone(item)
		copy.Model = if typeof(copy.Model) == 'Instance' then copy.Model else self:ResolveInventoryModel(copy, modelLookup)
		if not copy.Model then
			missingModel = true
		end
		table.insert(items, copy)
	end

	self:SetItems(items)

	if missingModel and (retryCount or 0) < 3 then
		task.delay(0.12, function()
			if self._alive and self._snapshotApplyId == applyId then
				self:ApplySnapshot(snapshot, (retryCount or 0) + 1)
			end
		end)
	end
end

function InventoryController:GetInventoryModelLookup(snapshot)
	local backpackModels = {}
	local equippedModels = {}
	local modelsById = {}
	local modelsBySlot = {}

	local function trackModel(model: Model, equipped: boolean)
		local modelId = model:GetAttribute(INVENTORY_MODEL_ID_ATTRIBUTE)
		if type(modelId) == 'string' then
			modelsById[modelId] = model
		end

		local slot = model:GetAttribute(INVENTORY_SLOT_ATTRIBUTE)
		if type(slot) == 'number' then
			modelsBySlot[slot] = model
		end

		if equipped then
			table.insert(equippedModels, model)
		else
			table.insert(backpackModels, model)
		end
	end

	if self.Backpack then
		for _, child in ipairs(self.Backpack:GetChildren()) do
			if isInventoryCandidate(child) then
				trackModel(child, false)
			end
		end
	end

	local character = self.Player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if isInventoryCandidate(child) then
				trackModel(child, true)
			end
		end
	end

	local backpackIndex = 0
	local equippedIndex = 0
	for _, item in ipairs(snapshot) do
		if not modelsBySlot[item.Slot] and item.Equipped then
			equippedIndex += 1
			modelsBySlot[item.Slot] = equippedModels[equippedIndex]
		elseif not modelsBySlot[item.Slot] then
			backpackIndex += 1
			modelsBySlot[item.Slot] = backpackModels[backpackIndex]
		end
	end

	return {
		ById = modelsById,
		BySlot = modelsBySlot,
	}
end

function InventoryController:ResolveInventoryModel(item, modelLookup)
	local modelId = item and item.ModelId
	if type(modelId) == 'string' then
		local model = modelLookup.ById[modelId]
		if model then
			return model
		end
	end

	return modelLookup.BySlot[item and item.Slot]
end

function InventoryController:SetItems(items)
	self.Items = items
	self.ItemsBySlot = {}
	self.EquippedSlot = nil

	for _, item in ipairs(items) do
		self.ItemsBySlot[item.Slot] = item
		if item.Equipped then
			self.EquippedSlot = item.Slot
		end
	end

	if self.SelectedSlot and not self.ItemsBySlot[self.SelectedSlot] then
		self.SelectedSlot = nil
	end

	self:SyncItemComponents()
	self.Changed:Fire(self.Items, self.SelectedSlot, self.EquippedSlot)
end

function InventoryController:GetComponentClassForItem(item)
	local itemType = item.ItemType
	if type(itemType) ~= 'string' or itemType == '' then
		return InventoryItemClient
	end

	if componentClassCache[itemType] ~= nil then
		return componentClassCache[itemType]
	end

	local candidates = {
		itemType .. 'Client',
		itemType .. 'InventoryItemClient',
	}

	for _, className in ipairs(candidates) do
		local ok, class = pcall(function()
			return Framework.Components[className]
		end)
		if ok and type(class) == 'table' then
			componentClassCache[itemType] = class
			return class
		end
	end

	componentClassCache[itemType] = InventoryItemClient
	return InventoryItemClient
end

function InventoryController:SyncItemComponents()
	local seen = {}
	local modelLookup = nil
	for _, item in ipairs(self.Items) do
		seen[item.Slot] = true
		local component = self.ItemComponents[item.Slot]
		local componentClass = self:GetComponentClassForItem(item)
		if not item.Model then
			modelLookup = modelLookup or self:GetInventoryModelLookup(self.Items)
			item.Model = self:ResolveInventoryModel(item, modelLookup)
		end
		if component and component.ItemType ~= item.ItemType then
			component:Destroy()
			component = nil
			self.ItemComponents[item.Slot] = nil
		end

		if component then
			if item.Model then
				component:SetModel(item.Model)
			end
			component:SetEquipped(item.Equipped)
		elseif item.Model then
			component = componentClass:new(item.Model, item.Slot, item.ItemType)
			component:SetEquipped(item.Equipped)
			self.ItemComponents[item.Slot] = component
		end
	end

	for slot, component in pairs(self.ItemComponents) do
		if not seen[slot] then
			component:Destroy()
			self.ItemComponents[slot] = nil
		end
	end
end

function InventoryController:GetItemComponent(slot: number)
	return self.ItemComponents[slot]
end

function InventoryController:GetItems()
	local copy = table.create(#self.Items)
	for index, item in ipairs(self.Items) do
		copy[index] = table.clone(item)
	end
	return copy
end

function InventoryController:GetSlotItem(slot: number)
	return self.ItemsBySlot[slot]
end

function InventoryController:RunInventoryAction(mode: string, slot: number?, toSlot: number?)
	if not self.ActionsEnabled then
		return false
	end

	self._queuedInventoryMode = mode
	self._queuedInventorySlot = slot
	self._queuedInventoryToSlot = toSlot
	if self._inventoryActionActive then
		return true
	end

	self._inventoryActionActive = true
	task.spawn(function()
		while self._queuedInventoryMode do
			if not self.ActionsEnabled then
				self._queuedInventoryMode = nil
				self._queuedInventorySlot = nil
				self._queuedInventoryToSlot = nil
				break
			end

			local currentMode = self._queuedInventoryMode
			local currentSlot = self._queuedInventorySlot
			local currentToSlot = self._queuedInventoryToSlot
			self._queuedInventoryMode = nil
			self._queuedInventorySlot = nil
			self._queuedInventoryToSlot = nil

			self._suppressModelSnapshotsUntil = os.clock() + 0.35

			local ok, snapshot = pcall(function()
				if currentMode == 'Unequip' then
					return self.InventoryService:UnequipItem()
				elseif currentMode == 'Equip' and currentSlot then
					return self.InventoryService:EquipSlot(currentSlot)
				elseif currentMode == 'Move' and currentSlot and currentToSlot then
					return self.InventoryService:MoveSlot(currentSlot, currentToSlot)
				end
				return nil
			end)
			if ok and snapshot and not self._queuedInventoryMode then
				self:ApplySnapshot(snapshot)
			elseif not ok then
				warn(('[InventoryController] Inventory action failed: %s'):format(tostring(snapshot)))
			end
		end
		self._inventoryActionActive = false
	end)

	return true
end

function InventoryController:ApplyOptimisticEquip(slot: number?)
	if self.EquippedSlot == slot then
		return
	end

	self.EquippedSlot = slot
	self.Changed:Fire(self.Items, self.SelectedSlot, self.EquippedSlot)
end

function InventoryController:ToggleSlot(slot: number)
	if not self.ActionsEnabled then
		return false
	end

	local item = self:GetSlotItem(slot)
	if not item then
		return false
	end

	self:SelectSlot(slot)
	local shouldUnequip = self.EquippedSlot == slot
	self:ApplyOptimisticEquip(if shouldUnequip then nil else slot)
	return self:RunInventoryAction(if shouldUnequip then 'Unequip' else 'Equip', slot)
end

function InventoryController:MoveSlot(fromSlot: number, toSlot: number)
	if not self.ActionsEnabled then
		return false
	end

	if fromSlot == toSlot or not self:GetSlotItem(fromSlot) then
		return false
	end

	return self:RunInventoryAction('Move', fromSlot, toSlot)
end

function InventoryController:EquipSlot(slot: number)
	if not self.ActionsEnabled then
		return false
	end

	local item = self:GetSlotItem(slot)
	if not item then
		return false
	end

	self:SelectSlot(slot)
	self:ApplyOptimisticEquip(slot)
	return self:RunInventoryAction('Equip', slot)
end

function InventoryController:SelectSlot(slot: number?)
	if slot ~= nil and not self.ItemsBySlot[slot] then
		return false
	end

	if self.SelectedSlot == slot then
		return true
	end

	self.SelectedSlot = slot
	self.Changed:Fire(self.Items, self.SelectedSlot, self.EquippedSlot)
	return true
end

function InventoryController:GetSelectedItem()
	return self.SelectedSlot and self.ItemsBySlot[self.SelectedSlot] or nil
end

function InventoryController:GetEquippedItem()
	return self.EquippedSlot and self.ItemsBySlot[self.EquippedSlot] or nil
end

function InventoryController:UnequipItem()
	if not self.ActionsEnabled then
		return false
	end

	self:ApplyOptimisticEquip(nil)
	return self:RunInventoryAction('Unequip', nil)
end

function InventoryController.Server:InventoryChanged(snapshot)
	if self._inventoryActionActive or self:ShouldSuppressModelSnapshot() then
		return
	end
	self:ApplySnapshot(snapshot)
end

return InventoryController
