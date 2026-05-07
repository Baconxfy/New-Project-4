local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local BaseClient = BaseComponent:Extend('BaseClient')


function BaseClient:Create(baseFolder: Folder)
	if not baseFolder then
		warn('[BaseClient] Missing base folder')
		return
	end

	self.BaseFolder = baseFolder
	self.SpawnLocation = baseFolder:FindFirstChildWhichIsA('SpawnLocation', true)
	self.Pads = {}

	local padsFolder = baseFolder:FindFirstChild('Pads', true)
	if not padsFolder then
		warn(('[BaseClient] %s is missing Pads'):format(baseFolder:GetFullName()))
		return
	end

	for _, padModel in ipairs(padsFolder:GetChildren()) do
		if padModel:IsA('Model') then
			table.insert(self.Pads, self.Framework.Components.PadClient:new(padModel))
		end
	end
end

return BaseClient
