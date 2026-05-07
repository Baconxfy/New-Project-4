local ProximityPromptService = game:GetService('ProximityPromptService')
local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local MicrowaveController = Framework:CreateController('MicrowaveController')

local MICROWAVE_PROMPT_NAME = 'MicrowavePrompt'

function MicrowaveController:Initialize()
	self.SetPowerRequested = Instance.new('BindableEvent')
	self.ActiveSession = nil
end

function MicrowaveController:Start()
	self.MicrowaveService = Framework:GetService('MicrowaveService')
	self:AddConnection(ProximityPromptService.PromptTriggered:Connect(function(prompt)
		self:HandlePromptTriggered(prompt)
	end))
end

function MicrowaveController:HandlePromptTriggered(prompt: ProximityPrompt)
	if prompt.Name ~= MICROWAVE_PROMPT_NAME or self.ActiveSession ~= nil then
		return
	end

	local session = self.MicrowaveService:StartOpening(prompt)
	if type(session) ~= 'table' or session.Ok ~= true then
		return
	end

	self.ActiveSession = session
end

function MicrowaveController.Server:ShowSetPower(session)
	self.ActiveSession = session
	self.SetPowerRequested:Fire(session)
	print('[MicrowaveController] Ready to show Set Power UI')
end

return MicrowaveController
