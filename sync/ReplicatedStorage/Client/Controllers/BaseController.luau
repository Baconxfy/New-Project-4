local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local BaseController = Framework:CreateController('BaseController')

function BaseController:Initialize()
	self.Pads = {}
	self.BaseClient = nil
end

function BaseController:Start()
	
end

function BaseController.Server:ClaimBase(baseFolder: Folder)
	if not baseFolder then
		warn('[BaseController] ClaimBase missing base folder')
		return
	end

	if self.BaseClient then
		self.BaseClient:Destroy()
	end
	self.BaseClient = Framework.Components.BaseClient:new(baseFolder)
end


return BaseController