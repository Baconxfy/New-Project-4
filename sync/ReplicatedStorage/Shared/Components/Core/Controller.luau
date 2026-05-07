local BaseComponent = require(game:GetService('ReplicatedStorage').Shared.Components:FindFirstChild('BaseComponent', true) :: ModuleScript)
local Controller = BaseComponent:Extend("Controller")
function Controller:Create(name:string)
	-- Example Trove usage:
	-- local Trove = require(game.ReplicatedStorage.Shared.Packages.Trove)
	-- self._trove = Trove.new()
	self.Name = name
	self.Server = {}
	
end


function Controller:Initialize() end
function Controller:Start() end

return Controller
