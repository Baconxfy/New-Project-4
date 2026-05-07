local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local BaseServer = BaseComponent:Extend('BaseServer')


function BaseServer:Create(baseFolder:Folder)
	self.BaseFolder = baseFolder
	self.SpawnLocation = baseFolder:FindFirstChildWhichIsA('SpawnLocation', true)
	self.Owner = nil
	self.PlayerNameTextLabel = baseFolder:FindFirstChild('PlayerName', true):FindFirstChildWhichIsA('TextLabel', true)
	self.PlayerNameTextLabel.Text = 'Unclaimed'
	self.Pads = {}
	self.Fridges = {}

	local padsFolder = baseFolder:FindFirstChild('Pads', true)
	if padsFolder then
		for _, padModel in ipairs(padsFolder:GetChildren()) do
			if padModel:IsA('Model') then
				table.insert(self.Pads, self.Framework.Components.PadServer:new(padModel))
			end
		end
	end

	for _, descendant in ipairs(baseFolder:GetDescendants()) do
		if descendant:IsA('Model') and descendant.Name == 'Fridge' then
			table.insert(self.Fridges, self.Framework.Components.FridgeServer:new(descendant, self))
		end
	end
end

function BaseServer:Claim(player:Player)
	if self.Owner ~= nil then return end
	self.Owner = player
	self.Framework:GetController('BaseController').Server.Fire:ClaimBase(player, self.BaseFolder)
	self.PlayerNameTextLabel.Text = player.DisplayName .. "'s Base"
end

function BaseServer:Unclaim()
	self.Owner = nil
	self.PlayerNameTextLabel.Text = 'Unclaimed'
	for _, fridge in ipairs(self.Fridges) do
		fridge:Reset()
	end
end

return BaseServer
