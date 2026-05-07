local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local PadServer = BaseComponent:Extend('PadServer')


function PadServer:Create(padModel:Model)
	self.Model = padModel
	self.PressureButton = padModel:FindFirstChild('Money Display', true)
	self.MoneyDisplayLabel = self.PressureButton:FindFirstChildWhichIsA('TextLabel', true)
	self.MoneyDisplayLabel.Text = ''
	self.CurrentBrainrot = nil
	self.CashToClaim = 0
	self.InteractPrompt = padModel:FindFirstChild('PadPrompt', true)
--	self.InteractPrompt.Enabled = false
end


return PadServer
