local ReplicatedStorage = game:GetService('ReplicatedStorage')
local HttpService = game:GetService('HttpService')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local InventoryItemServer = BaseComponent:Extend('InventoryItemServer')

local DEFAULT_ITEM_TYPE_ATTRIBUTE = 'ItemType'
local INVENTORY_SLOT_ATTRIBUTE = 'InventorySlot'
local INVENTORY_MODEL_ID_ATTRIBUTE = 'InventoryModelId'

local function getItemTypeAttribute(framework): string
	return (framework and framework.Config and framework.Config.Inventory and framework.Config.Inventory.ItemTypeAttribute) or DEFAULT_ITEM_TYPE_ATTRIBUTE
end

function InventoryItemServer:Create(model: Model?, itemType: string?)
	if model then
		self:Configure(model, itemType)
	end
end

function InventoryItemServer:Configure(model: Model, itemType: string?)
	self.Model = model
	self.ItemType = itemType or InventoryItemServer.GetItemType(model)
	self.Slot = 0

	local itemTypeAttribute = getItemTypeAttribute(self.Framework)
	if model:GetAttribute(itemTypeAttribute) ~= self.ItemType then
		model:SetAttribute(itemTypeAttribute, self.ItemType)
	end

	if type(model:GetAttribute(INVENTORY_MODEL_ID_ATTRIBUTE)) ~= 'string' then
		model:SetAttribute(INVENTORY_MODEL_ID_ATTRIBUTE, HttpService:GenerateGUID(false))
	end
end

function InventoryItemServer.GetItemType(model: Model): string
	local itemType = model:GetAttribute(DEFAULT_ITEM_TYPE_ATTRIBUTE)
	if type(itemType) == 'string' and itemType ~= '' then
		return itemType
	end
	return model.Name
end

function InventoryItemServer:SetSlot(slot: number)
	self.Slot = slot
	if self.Model and self.Model.Parent then
		self.Model:SetAttribute(INVENTORY_SLOT_ATTRIBUTE, slot)
	end
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
		ModelId = self.Model:GetAttribute(INVENTORY_MODEL_ID_ATTRIBUTE),
		ModelName = self.Model.Name,
	}
end

return InventoryItemServer
