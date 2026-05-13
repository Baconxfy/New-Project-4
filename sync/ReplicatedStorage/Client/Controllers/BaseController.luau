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
		local oldBaseClient = self.BaseClient
		self.BaseClient = nil
		oldBaseClient:Destroy()
	end
	self.BaseClient = Framework.Components.BaseClient:new(baseFolder)
end

function BaseController.Server:PadUpgradeChanged(state)
	if self.BaseClient and rawget(self.BaseClient, '_alive') then
		self.BaseClient:ApplyPadUpgradeState(state)
	end
end


return BaseController
