local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local InventoryItemServer = BaseComponent:Extend('InventoryItemServer')

function InventoryItemServer:Create(model: Model, itemType: string)
	self.Model = model
	self.ItemType = itemType
	self.Slot = 0
	self.ItemName = model.Name
end



function InventoryItemServer:SetSlot(slot: number)
	self.Slot = slot
end

function InventoryItemServer:IsEquipped(character: Model?): boolean
	return character ~= nil and self.Model.Parent == character
end

function InventoryItemServer:IsOwnedBy(backpack: Backpack?, character: Model?): boolean
	return self.Model.Parent == backpack or self.Model.Parent == character
end

function InventoryItemServer:Serialize(character: Model?)
	return {
		Slot = self.Slot,
		ItemType = self.ItemType,
		Equipped = self:IsEquipped(character),
	}
end

return InventoryItemServer
