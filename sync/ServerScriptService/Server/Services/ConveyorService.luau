local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local ConveyorService = Framework:CreateService("ConveyorService")

local SPEED = 80

function ConveyorService:Start()
	local conveyor = workspace:WaitForChild("Conveyor")

	self:SetConveyor(conveyor:WaitForChild("ConveyorUp"), -1)
	self:SetConveyor(conveyor:WaitForChild("ConveyorDown"), 1)
end

function ConveyorService:SetConveyor(part: BasePart, direction: number)
	part.Anchored = true
	part.AssemblyLinearVelocity = part.CFrame.RightVector * SPEED * direction
end

return ConveyorService
