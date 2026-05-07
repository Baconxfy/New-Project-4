local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local InventoryItemClient = BaseComponent:Extend('InventoryItemClient')

function InventoryItemClient:Create(model: Model, slot: number, itemType: string)
	self.Model = model
	self.Slot = slot
	self.ItemType = itemType
	self.Equipped = false
end

function InventoryItemClient:SetModel(model: Model)
	self.Model = model
end

function InventoryItemClient:SetEquipped(equipped: boolean)
	self.Equipped = equipped == true
end

function InventoryItemClient:GetSlot(): number
	return self.Slot
end

function InventoryItemClient:IsEquipped(): boolean
	return self.Equipped
end

function InventoryItemClient:Equip()
	return self.Framework:GetService('InventoryService'):EquipSlot(self.Slot)
end

function InventoryItemClient:Unequip()
	return self.Framework:GetService('InventoryService'):UnequipItem()
end

function InventoryItemClient:ToggleEquip()
	return self.Framework:GetService('InventoryService'):ToggleSlot(self.Slot)
end

return InventoryItemClient
