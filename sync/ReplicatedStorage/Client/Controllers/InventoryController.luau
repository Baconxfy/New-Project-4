local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local InventoryController = Framework:CreateController('InventoryController')

local LUCKYBLOCK_ITEM_TYPE = 'Luckyblock'
local InventoryItemClient = Framework.Components.InventoryItemClient
local LuckyblockClient = Framework.Components.LuckyblockClient

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
	self.Items = {}
	self.ItemsBySlot = {}
	self.SelectedSlot = nil
	self.EquippedSlot = nil
	self.KeybindsEnabled = true
	self.Changed = Instance.new('BindableEvent')
	self.BackpackToggleRequested = Instance.new('BindableEvent')
	self.ItemComponents = {}
	self._connections = {}
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
	self:RequestInitialSnapshot()
end

function InventoryController:BindBackpack(backpack: Backpack)
	self:DisconnectConnections(self._connections)

	table.insert(self._connections, backpack.ChildAdded:Connect(function(child)
		if isInventoryCandidate(child) then
			self:RequestInitialSnapshot()
		end
	end))

	table.insert(self._connections, backpack.ChildRemoved:Connect(function(child)
		if isInventoryCandidate(child) then
			self:RequestInitialSnapshot()
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
		if isInventoryCandidate(child) then
			self:RequestInitialSnapshot()
		end
	end))

	table.insert(self._characterConnections, character.ChildRemoved:Connect(function(child)
		if isInventoryCandidate(child) then
			self:RequestInitialSnapshot()
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

function InventoryController:SetKeybindsEnabled(enabled: boolean)
	self.KeybindsEnabled = enabled == true
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

function InventoryController:ApplySnapshot(snapshot)
	local items = {}
	local modelsBySlot = self:GetInventoryModelsBySlot(snapshot or {})

	for _, item in ipairs(snapshot or {}) do
		local copy = table.clone(item)
		copy.Model = modelsBySlot[copy.Slot]
		table.insert(items, copy)
	end

	self:SetItems(items)
end

function InventoryController:GetInventoryModelsBySlot(snapshot)
	local backpackModels = {}
	local equippedModels = {}

	if self.Backpack then
		for _, child in ipairs(self.Backpack:GetChildren()) do
			if isInventoryCandidate(child) then
				table.insert(backpackModels, child)
			end
		end
	end

	local character = self.Player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if isInventoryCandidate(child) then
				table.insert(equippedModels, child)
			end
		end
	end

	local modelsBySlot = {}
	local backpackIndex = 0
	local equippedIndex = 0
	for _, item in ipairs(snapshot) do
		if item.Equipped then
			equippedIndex += 1
			modelsBySlot[item.Slot] = equippedModels[equippedIndex]
		else
			backpackIndex += 1
			modelsBySlot[item.Slot] = backpackModels[backpackIndex]
		end
	end

	return modelsBySlot
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
	self.Changed:Fire(self:GetItems(), self.SelectedSlot, self.EquippedSlot)
end

function InventoryController:GetComponentClassForItem(item)
	if item.ItemType == LUCKYBLOCK_ITEM_TYPE then
		return LuckyblockClient
	end
	return InventoryItemClient
end

function InventoryController:SyncItemComponents()
	local seen = {}
	for _, item in ipairs(self.Items) do
		seen[item.Slot] = true
		local component = self.ItemComponents[item.Slot]
		if component then
			if item.Model then
				component:SetModel(item.Model)
			end
			component:SetEquipped(item.Equipped)
		elseif item.Model then
			component = self:GetComponentClassForItem(item):new(item.Model, item.Slot, item.ItemType)
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

function InventoryController:ToggleSlot(slot: number)
	local item = self:GetSlotItem(slot)
	if not item then
		return false
	end

	self:SelectSlot(slot)
	local snapshot = self.InventoryService:ToggleSlot(slot)
	self:ApplySnapshot(snapshot)
	return true
end

function InventoryController:EquipSlot(slot: number)
	local item = self:GetSlotItem(slot)
	if not item then
		return false
	end

	self:SelectSlot(slot)
	local snapshot = self.InventoryService:EquipSlot(slot)
	self:ApplySnapshot(snapshot)
	return true
end

function InventoryController:SelectSlot(slot: number?)
	if slot ~= nil and not self.ItemsBySlot[slot] then
		return false
	end

	self.SelectedSlot = slot
	self.Changed:Fire(self:GetItems(), self.SelectedSlot, self.EquippedSlot)
	return true
end

function InventoryController:GetSelectedItem()
	return self.SelectedSlot and self.ItemsBySlot[self.SelectedSlot] or nil
end

function InventoryController:GetEquippedItem()
	return self.EquippedSlot and self.ItemsBySlot[self.EquippedSlot] or nil
end

function InventoryController:UnequipItem()
	local snapshot = self.InventoryService:UnequipItem()
	self:ApplySnapshot(snapshot)
	return true
end

function InventoryController.Server:InventoryChanged(snapshot)
	self:ApplySnapshot(snapshot)
end

return InventoryController
