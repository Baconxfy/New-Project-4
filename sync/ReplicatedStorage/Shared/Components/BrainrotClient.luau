local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)'))

local BrainrotClient = BaseComponent:Extend('BrainrotClient')


function BrainrotClient:Create(model: Model)
	self.Model = model
	self.Name = model.Name
	
end

return BrainrotClient
