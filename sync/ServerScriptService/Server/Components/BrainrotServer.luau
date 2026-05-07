local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)'))

local Brainrot = BaseComponent:Extend('Brainrot')


function Brainrot:Create(model: Model)
	self.Model = model
	self.Name = model.Name
	self.Level = 1
	if self.Framework.Config.Brainrots[self.Name] == nil then
		warn('Attempted to set up an unknown brainrot')
		return
	end
	self.MoneyPerSecond = self.Framework.Config.Brainrots[self.Name].Price
end

return Brainrot
