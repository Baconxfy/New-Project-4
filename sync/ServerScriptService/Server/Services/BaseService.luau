local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local Players = game:GetService('Players')

local BaseService = Framework:CreateService("BaseService")

function BaseService:Initialize()
	self.Bases = {}
end

function BaseService:Start()
	self:SetupBases()
	Players.PlayerAdded:Connect(function(player)
		self:AssignBaseForPlayer(player)
		
	end)
	for i, player in ipairs(Players:GetChildren()) do
		if self:GetBaseFromPlayer(player) ~= nil then return end
		self:AssignBaseForPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local base = self:GetBaseFromPlayer(player)
		if base then base:Unclaim() end
	end)
end

function BaseService:AssignBaseForPlayer(player)
	local base = self:GetVacantBase()
	if base then
		base:Claim(player)
		player.RespawnLocation = base.SpawnLocation
	end
end
function BaseService:SetupBases()
	local baseFolders = workspace:WaitForChild('Bases'):GetChildren()
	table.sort(baseFolders, function(a, b)
		return (tonumber(a.Name:match('%d+')) or math.huge) < (tonumber(b.Name:match('%d+')) or math.huge)
	end)

	for _, baseFolder in ipairs(baseFolders) do
		table.insert(self.Bases, Framework.Components.BaseServer:new(baseFolder))
	end
end

function BaseService:GetBaseFromPlayer(player:Player)
	for i, base in ipairs(self.Bases) do
		if base.Owner == player then
			return base
		end
	end
	return nil
end

function BaseService:GetVacantBase()
	for i, base in ipairs(self.Bases) do
		if base.Owner == nil then
			return base
		end
	end
	return nil
end



return BaseService
