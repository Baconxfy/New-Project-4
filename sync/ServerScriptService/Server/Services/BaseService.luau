local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local Players = game:GetService('Players')

local BaseService = Framework:CreateService("BaseService")

function BaseService:Initialize()
	self.Bases = {}
end

function BaseService:Start()
	self:SetupBases()

	Players.PlayerAdded:Connect(function(player)
		self:AssignBaseForPlayerWhenReady(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:AssignBaseForPlayerWhenReady(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local base = self:GetBaseFromPlayer(player)
		if base then base:Unclaim() end
	end)
end

function BaseService:AssignBaseForPlayerWhenReady(player: Player)
	task.spawn(function()
		local dataService = Framework:GetService('DataService')
		local profile = dataService:GetProfileAsync(player.UserId)
		if not profile then
			return
		end
		if player.Parent == Players and self:GetBaseFromPlayer(player) == nil then
			self:AssignBaseForPlayer(player)
		end
	end)
end

function BaseService:AssignBaseForPlayer(player)
	local base = self:GetVacantBase()
	if base then
		self:NormalizePlayerStage(player, base)
		base:Claim(player)
		player.RespawnLocation = base.SpawnLocation
	end
end

function BaseService:GetPadsConfig()
	return (Framework.Config and Framework.Config.Pads) or {}
end

function BaseService:GetBaseConfig()
	return (Framework.Config and Framework.Config.Base) or {}
end

function BaseService:GetBaseStageDataKey(): string
	return self:GetBaseConfig().StageDataKey or 'BaseStage'
end

function BaseService:GetDefaultStage(): number
	return tonumber(self:GetBaseConfig().DefaultStage) or 1
end

function BaseService:GetStageConfig(stage: number)
	local config = self:GetBaseConfig()
	return config.Stages and config.Stages[stage] or nil
end

function BaseService:GetNextStage(stage: number): number?
	local nextStage = stage + 1
	return if self:GetStageConfig(nextStage) then nextStage else nil
end

function BaseService:GetPlayerStage(player: Player): number
	local dataService = Framework:GetService('DataService')
	local stage = dataService:GetData(player.UserId, self:GetBaseStageDataKey())
	if type(stage) ~= 'number' or not self:GetStageConfig(stage) then
		stage = self:GetDefaultStage()
		dataService:UpdatePlayerData(player.UserId, self:GetBaseStageDataKey(), stage)
	end
	return math.floor(stage)
end

function BaseService:SetPlayerStage(player: Player, stage: number)
	local dataService = Framework:GetService('DataService')
	local value = math.max(1, math.floor(stage))
	if not self:GetStageConfig(value) then
		return false
	end
	return dataService:UpdatePlayerData(player.UserId, self:GetBaseStageDataKey(), value)
end

function BaseService:GetPadUnlockDataKey(): string
	return self:GetPadsConfig().UnlockedDataKey or 'PadsUnlocked'
end

function BaseService:GetDefaultUnlockedPadCount(): number
	return tonumber(self:GetPadsConfig().DefaultEnabledCount) or 1
end

function BaseService:GetUnlockedPadCount(player: Player): number
	local dataService = Framework:GetService('DataService')
	local count = dataService:GetData(player.UserId, self:GetPadUnlockDataKey())
	if type(count) ~= 'number' then
		count = self:GetDefaultUnlockedPadCount()
		dataService:UpdatePlayerData(player.UserId, self:GetPadUnlockDataKey(), count)
	end
	return math.max(self:GetDefaultUnlockedPadCount(), math.floor(count))
end

function BaseService:NormalizePlayerStage(player: Player, base)
	local stage = self:GetPlayerStage(player)
	local unlockedCount = self:GetUnlockedPadCount(player)
	while base and unlockedCount > base:GetStagePadCount(stage) do
		local nextStage = base:GetNextStage(stage)
		if not nextStage then
			break
		end

		if not self:SetPlayerStage(player, nextStage) then
			break
		end

		stage = nextStage
		self:SetUnlockedPadCount(player, unlockedCount)
	end

	return stage, unlockedCount
end

function BaseService:GetStageForPadIndex(currentStage: number, padIndex: number, base): number?
	local stage = currentStage
	while base and padIndex > base:GetStagePadCount(stage) do
		local nextStage = base:GetNextStage(stage)
		if not nextStage then
			return nil
		end
		stage = nextStage
	end
	return stage
end

function BaseService:GetPreviousStagePadCount(stage: number): number
	local previousStage = stage - 1
	if previousStage < 1 then
		return 0
	end

	local config = self:GetStageConfig(previousStage)
	return tonumber(config and config.Pads) or 0
end

function BaseService:SetUnlockedPadCount(player: Player, count: number)
	local dataService = Framework:GetService('DataService')
	local value = math.max(self:GetDefaultUnlockedPadCount(), math.floor(count))
	return dataService:UpdatePlayerData(player.UserId, self:GetPadUnlockDataKey(), value)
end

function BaseService:GetPadPrice(stage: number, padIndex: number): number?
	local stageUnlocks = self:GetPadsConfig().StageUnlocks and self:GetPadsConfig().StageUnlocks[stage]
	local unlockConfig = stageUnlocks and stageUnlocks[padIndex]
	if not unlockConfig then
		local localPadIndex = padIndex - self:GetPreviousStagePadCount(stage) + 1
		unlockConfig = stageUnlocks and stageUnlocks[localPadIndex]
	end
	if not unlockConfig then
		unlockConfig = self:GetPadsConfig().Unlocks and self:GetPadsConfig().Unlocks[padIndex]
	end
	local cost = unlockConfig and unlockConfig.Cost
	return if type(cost) == 'number' then cost else nil
end

function BaseService:GetPadUpgradeState(player: Player)
	local base = self:GetBaseFromPlayer(player)
	if not base then
		return {
			Ok = false,
			Reason = 'NoBase',
		}
	end

	local stage = self:GetPlayerStage(player)
	local unlockedCount = math.min(self:GetUnlockedPadCount(player), base:GetTotalPads())
	local nextPadIndex = unlockedCount + 1
	local targetStage = self:GetStageForPadIndex(stage, nextPadIndex, base)
	local totalPads = base:GetStagePadCount(stage)
	local maxed = targetStage == nil
	local nextPrice = if maxed or targetStage == nil then nil else self:GetPadPrice(targetStage, nextPadIndex)
	local cash = Framework:GetService('DataService'):GetData(player.UserId, 'Cash') or 0

	return {
		Ok = true,
		Stage = stage,
		TargetStage = targetStage,
		UnlockedCount = unlockedCount,
		NextPadIndex = if maxed then nil else nextPadIndex,
		NextPrice = nextPrice,
		TotalPads = totalPads,
		Maxed = maxed,
		CanAfford = nextPrice ~= nil and cash >= nextPrice,
		Cash = cash,
	}
end

function BaseService:RefreshPadUpgrade(player: Player)
	local state = self:GetPadUpgradeState(player)
	local base = self:GetBaseFromPlayer(player)
	if base then
		base:UpdatePadUpgradeDisplay(state)
	end
	Framework:GetController('BaseController').Server.Fire:PadUpgradeChanged(player, state)
	return state
end

function BaseService:BuyNextPad(player: Player)
	local state = self:GetPadUpgradeState(player)
	if not state.Ok or state.Maxed or not state.NextPadIndex or not state.NextPrice then
		return state
	end

	if state.Cash < state.NextPrice then
		state.Reason = 'NotEnoughCash'
		return state
	end

	local dataService = Framework:GetService('DataService')
	if not dataService:AddPlayerData(player.UserId, 'Cash', -state.NextPrice) then
		state.Ok = false
		state.Reason = 'SpendFailed'
		return state
	end

	if not self:SetUnlockedPadCount(player, state.NextPadIndex) then
		dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
		state.Ok = false
		state.Reason = 'SaveFailed'
		return state
	end

	local base = self:GetBaseFromPlayer(player)
	local targetStage = state.TargetStage
	local changedStage = base and targetStage and targetStage ~= state.Stage
	if base and changedStage then
		if not self:SetPlayerStage(player, targetStage) then
			dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
			self:SetUnlockedPadCount(player, state.UnlockedCount)
			state.Ok = false
			state.Reason = 'StageSaveFailed'
			return state
		end

		local carriedUnlockedCount = state.NextPadIndex
		self:SetUnlockedPadCount(player, carriedUnlockedCount)
		if not base:SetStage(targetStage, carriedUnlockedCount) then
			dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
			self:SetPlayerStage(player, state.Stage)
			self:SetUnlockedPadCount(player, state.UnlockedCount)
			state.Ok = false
			state.Reason = 'StageLoadFailed'
			return state
		end
		player.RespawnLocation = base.SpawnLocation
		local baseFolder = base.BaseFolder
		task.defer(function()
			if player.Parent == Players and base.Owner == player then
				Framework:GetController('BaseController').Server.Fire:ClaimBase(player, baseFolder)
				self:RefreshPadUpgrade(player)
			end
		end)
	elseif base then
		base:ApplyPadUnlockCount(state.NextPadIndex)
	end

	return self:RefreshPadUpgrade(player)
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

function BaseService.Client:GetPadUpgradeState(player: Player)
	return self:GetPadUpgradeState(player)
end

function BaseService.Client:BuyNextPad(player: Player)
	return self:BuyNextPad(player)
end



return BaseService
