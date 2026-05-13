local ReplicatedStorage = game:GetService('ReplicatedStorage')

local InventoryItemClient = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('InventoryItemClient', true) :: ModuleScript)
local BrainrotBillboard = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('BrainrotBillboard'))

local BrainrotClient = InventoryItemClient:Extend('BrainrotClient')

function BrainrotClient:Create(model: Model, slot: number, itemType: string)
	InventoryItemClient.Create(self, model, slot, itemType)
	self:RefreshBrainrot()
end

function BrainrotClient:SetModel(model: Model)
	InventoryItemClient.SetModel(self, model)
	self:RefreshBrainrot()
end

function BrainrotClient:SetEquipped(equipped: boolean)
	InventoryItemClient.SetEquipped(self, equipped)
end

function BrainrotClient:RefreshBrainrot()
	self.BrainrotName = self.Model and self.Model.Name or nil
	if self.Model then
		BrainrotBillboard.Attach(self.Model, self.Framework, {
			Name = self.BrainrotName,
			ModelName = self.BrainrotName,
		})
	end
end

return BrainrotClient
