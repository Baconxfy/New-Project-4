local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local LuckyblockServer = BaseComponent:Extend('LuckyblockServer')



local function prepModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BasePart') then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

function LuckyblockServer:Create(template: Model, blockName: string, parent: Instance, spawnPart: BasePart, minScale: number?, maxScale: number?)
	self.BlockName = blockName
	self.Progress = 0
	self.MinScale = minScale
	self.MaxScale = maxScale
	self.SpawnPart = spawnPart

	self.Model = template:Clone()
	self.Model.Name = blockName
	self.Model.Parent = parent
	prepModel(self.Model)
	self:Refresh()
end

function LuckyblockServer:GetSpawnCFrame(): CFrame
	local _, size = self.Model:GetBoundingBox()
	return self.SpawnPart.CFrame * CFrame.new(0, (self.SpawnPart.Size.Y * 0.5) + (size.Y * 0.5), 0)
end

function LuckyblockServer:Refresh()
	local scale = self.MinScale + ((self.MaxScale - self.MinScale) * self.Progress)
	self.Model:ScaleTo(scale)
	self.Model:PivotTo(self:GetSpawnCFrame())
end

function LuckyblockServer:SetProgress(progress: number)
	self.Progress = math.clamp(progress, 0, 1)
	self:Refresh()
end

function LuckyblockServer:CleanUp()
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
end

return LuckyblockServer
