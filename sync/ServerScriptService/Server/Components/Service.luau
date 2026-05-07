local BaseComponent = require(game:GetService('ReplicatedStorage').Shared.Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local Service = BaseComponent:Extend("Service")


function Service:Create(name:string)
	self.Name = name
	self.Client = {}
end


function Service:Initialize() end
function Service:Start() end

return Service
