local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local MicrowaveService = Framework:CreateService('MicrowaveService')

local DEFAULT_MICROWAVE_MODEL_NAME = 'Microwave'
local DEFAULT_MICROWAVE_PROMPT_NAME = 'MicrowavePrompt'
local DEFAULT_SESSION_BLOCK_FOLDER_NAME = 'InsertedLuckyblock'
local DEFAULT_RESULT_FOLDER_NAME = 'MicrowaveResult'
local DEFAULT_LUCKYBLOCK_SLOT_NAME = 'LuckyblockSlot'
local DEFAULT_INTERACT_DISTANCE_PADDING = 6
local DEFAULT_COOK_TIME = 5
local DEFAULT_STOP_READY_PADDING = 0.25
local DEFAULT_PERFECT_THRESHOLD = 0.91
local DEFAULT_OKAY_THRESHOLD = 0.68
local DEFAULT_SET_POWER_SPEED = 1.4
local DEFAULT_STOP_MICROWAVE_SPEED = 1.7
local DEFAULT_REWARD_NAME = 'Noobini Pizzanini'
local DEFAULT_PREVIEW_COUNT = 18
local DEFAULT_POWER_LUCK_BONUS = 25
local DEFAULT_MUTATION = 'Normal'

local BRAINROT_MODELS = game:GetService('ReplicatedStorage'):WaitForChild('Assets'):WaitForChild('Brainrots')
local NORMAL_BRAINROT_MODELS = BRAINROT_MODELS:WaitForChild('Normal')

local function getMicrowaveConfig(framework)
	return (framework and framework.Config and framework.Config.Microwave) or {}
end

local function getMicrowaveMinigameConfig(framework)
	return getMicrowaveConfig(framework).Minigame or {}
end

local function getRollConfig(framework)
	return getMicrowaveConfig(framework).Roll or {}
end

local function getTimingResult(percent: number, perfectThreshold: number, okayThreshold: number): string
	if percent >= perfectThreshold then
		return 'Perfect'
	elseif percent >= okayThreshold then
		return 'Okay'
	end
	return 'Bad'
end

local function getTimingWeight(percent: number, result: string?): number
	local base = math.clamp(tonumber(percent) or 0, 0, 1)
	if result == 'Perfect' then
		return base
	elseif result == 'Okay' then
		return base * 0.65
	end
	return base * 0.22
end

local function getBlockOrder(config)
	local order = {}
	for name, blockConfig in pairs(config or {}) do
		if type(blockConfig) == 'table' and tonumber(blockConfig.XpRequired) then
			table.insert(order, name)
		end
	end
	table.sort(order, function(a, b)
		local aRequired = tonumber(config[a].XpRequired) or math.huge
		local bRequired = tonumber(config[b].XpRequired) or math.huge
		if aRequired == bRequired then
			return a < b
		end
		return aRequired < bRequired
	end)
	return order
end

local function findAncestorModel(instance: Instance, modelName: string): Model?
	local current = instance
	while current and current ~= workspace do
		if current:IsA('Model') and current.Name == modelName then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function getPromptPart(prompt: ProximityPrompt): BasePart?
	return prompt.Parent and prompt.Parent:IsA('BasePart') and prompt.Parent or nil
end

local function prepInsertedBlock(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('WeldConstraint') then
			descendant:Destroy()
		elseif descendant:IsA('BasePart') then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = false
		end
	end
end

local function prepResultModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BasePart') then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function normalizeName(value: any): string
	return tostring(value or ''):lower():gsub('%W', '')
end

local function findModelByLooseName(root: Instance, modelName: string): Model?
	local wanted = normalizeName(modelName)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA('Model') and normalizeName(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

local function findDirectChildByLooseName(root: Instance, childName: string): Instance?
	local wanted = normalizeName(childName)
	for _, child in ipairs(root:GetChildren()) do
		if normalizeName(child.Name) == wanted then
			return child
		end
	end
	return nil
end

local function findMutationFolder(mutationName: string?): Instance?
	if not mutationName or mutationName == DEFAULT_MUTATION then
		return nil
	end

	return BRAINROT_MODELS:FindFirstChild(mutationName) or findDirectChildByLooseName(BRAINROT_MODELS, mutationName)
end

local function findBrainrotTemplateInRoot(root: Instance, modelName: string, rarity: string?): Model?
	if type(rarity) == 'string' then
		local rarityFolder = root:FindFirstChild(rarity)
		local template = rarityFolder and rarityFolder:FindFirstChild(modelName)
		if template and template:IsA('Model') then
			return template
		end
		if rarityFolder then
			template = findModelByLooseName(rarityFolder, modelName)
			if template then
				return template
			end
		end
	end

	local directTemplate = root:FindFirstChild(modelName, true)
	if directTemplate and directTemplate:IsA('Model') then
		return directTemplate
	end
	return findModelByLooseName(root, modelName)
end

local function findBrainrotTemplate(rewardName: string, rewardConfig, mutationName: string?): Model?
	local rarity = type(rewardConfig) == 'table' and rewardConfig.Rarity or nil
	local modelName = tostring((type(rewardConfig) == 'table' and rewardConfig.ModelName) or rewardName)
	local mutationFolder = findMutationFolder(mutationName)

	if mutationFolder then
		local template = findBrainrotTemplateInRoot(mutationFolder, modelName, rarity)
		if template then
			return template
		end
	end

	return findBrainrotTemplateInRoot(NORMAL_BRAINROT_MODELS, modelName, rarity)
end

function MicrowaveService:Initialize()
	self.ActiveSessions = {}
	self.PromptConnections = {}
	self.Random = Random.new()
end

function MicrowaveService:Start()
	local promptName = getMicrowaveConfig(self.Framework).PromptName or DEFAULT_MICROWAVE_PROMPT_NAME
	local function trackPrompt(prompt: ProximityPrompt)
		if self.PromptConnections[prompt] then
			return
		end
		prompt.Enabled = true
		self.PromptConnections[prompt] = prompt.Triggered:Connect(function(player)
			self:StartOpening(player, prompt)
		end)
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA('ProximityPrompt') and descendant.Name == promptName then
			trackPrompt(descendant)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA('ProximityPrompt') and descendant.Name == promptName then
			trackPrompt(descendant)
		end
	end)
end

function MicrowaveService:CleanupSession(player: Player, returnLuckyblock: boolean?)
	local session = self.ActiveSessions[player]
	if not session then
		return nil
	end

	local inventoryService = self.Framework:GetService('InventoryService')

	if returnLuckyblock and session.LuckyblockModel and session.LuckyblockModel:IsA('Model') then
		inventoryService:AddItem(player, session.LuckyblockModel, 'Luckyblock', session.LuckyblockName)
	end

	local microwave = session.Microwave
	if microwave and microwave:IsA('Model') then
		local config = getMicrowaveConfig(self.Framework)
		self:ClearFolder(microwave, config.SessionBlockFolderName or DEFAULT_SESSION_BLOCK_FOLDER_NAME)
		self:ClearFolder(microwave, config.ResultFolderName or DEFAULT_RESULT_FOLDER_NAME)
	end

	local prompt = session.Prompt
	if prompt and prompt:IsA('ProximityPrompt') then
		prompt.Enabled = true
	end

	self.ActiveSessions[player] = nil
	if inventoryService and inventoryService.SetInventoryLocked then
		inventoryService:SetInventoryLocked(player, false)
	end
	return session
end

function MicrowaveService:ResolveActiveSession(player: Player)
	local session = self.ActiveSessions[player]
	if not session then
		return nil
	end

	if session.Phase == 'Revealing' and session.RewardModel and session.RewardModel:IsA('Model') then
		local inventoryService = self.Framework:GetService('InventoryService')
		inventoryService:AddItem(player, session.RewardModel, 'Brainrot', session.RewardName)
		return self:CleanupSession(player, false)
	end

	return self:CleanupSession(player, true)
end

function MicrowaveService:GetBaseForPrompt(prompt: ProximityPrompt)
	local baseService = self.Framework:GetService('BaseService')
	for _, base in ipairs(baseService.Bases) do
		if prompt:IsDescendantOf(base.BaseFolder) then
			return base
		end
	end
	return nil
end

function MicrowaveService:IsPlayerNearPrompt(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local promptPart = getPromptPart(prompt)
	if not root or not root:IsA('BasePart') or not promptPart then
		return false
	end

	local config = getMicrowaveConfig(self.Framework)
	local maxDistance = prompt.MaxActivationDistance + (config.InteractDistancePadding or DEFAULT_INTERACT_DISTANCE_PADDING)
	return (root.Position - promptPart.Position).Magnitude <= maxDistance
end

function MicrowaveService:GetOrCreateSlot(microwave: Model, prompt: ProximityPrompt): BasePart
	local config = getMicrowaveConfig(self.Framework)
	local slotName = config.LuckyblockSlotName or DEFAULT_LUCKYBLOCK_SLOT_NAME
	local existing = microwave:FindFirstChild(slotName, true)
	if existing and existing:IsA('BasePart') then
		return existing
	end

	warn(('[MicrowaveService] %s is missing %s; using temporary fallback slot'):format(microwave:GetFullName(), slotName))
	local promptPart = getPromptPart(prompt)
	local _, microwaveSize = microwave:GetBoundingBox()
	local slot = Instance.new('Part')
	slot.Name = slotName
	slot.Size = Vector3.new(1, 1, 1)
	slot.Transparency = 1
	slot.Anchored = true
	slot.CanCollide = false
	slot.CanTouch = false
	slot.CanQuery = false
	slot.CFrame = (promptPart and promptPart.CFrame or microwave:GetPivot()) * CFrame.new(0, -microwaveSize.Y * 0.25, -1)
	slot.Parent = microwave
	return slot
end

function MicrowaveService:GetRewardName(): string
	local rewardName = getMicrowaveConfig(self.Framework).DefaultRewardName or DEFAULT_REWARD_NAME
	local rewardConfig = (self.Framework.Config.Brainrots or {})[rewardName]
	if findBrainrotTemplate(rewardName, rewardConfig) then
		return rewardName
	end

	for configuredName, config in pairs(self.Framework.Config.Brainrots or {}) do
		if findBrainrotTemplate(configuredName, config) then
			rewardName = configuredName
			return rewardName
		end
	end

	return rewardName
end

function MicrowaveService:GetLuckyblockLuck(_luckyblock: Model, luckyblockName: string?): number
	local luckyblockConfig = self.Framework.Config.Luckyblocks or {}
	local rollConfig = getRollConfig(self.Framework)
	local blockOrder = getBlockOrder(luckyblockConfig)
	local blockIndex = luckyblockName and table.find(blockOrder, luckyblockName) or 1
	local blockConfig = luckyblockName and luckyblockConfig[luckyblockName] or nil
	local baseLuck = tonumber(rollConfig.BaseLuck) or 1
	local tierJump = tonumber(rollConfig.TierLuckJump) or 1.75
	local inTierBonus = tonumber(rollConfig.InTierLuckBonus) or 0.55
	local luckBonus = tonumber(blockConfig and blockConfig.LuckBonus) or 0
	local xp = tonumber(blockConfig and blockConfig.XpRequired) or 0
	local currentRequired = tonumber(blockConfig and blockConfig.XpRequired) or 0
	local nextRequired = blockIndex and tonumber(luckyblockConfig[blockOrder[blockIndex + 1]] and luckyblockConfig[blockOrder[blockIndex + 1]].XpRequired) or math.huge
	local progress = 0

	if nextRequired and nextRequired ~= math.huge and nextRequired > currentRequired then
		progress = math.clamp((xp - currentRequired) / (nextRequired - currentRequired), 0, 1)
	end

	return math.max(0, baseLuck + (((blockIndex or 1) - 1) * tierJump) + luckBonus + (progress * inTierBonus))
end

function MicrowaveService:GetTimingLuckBonus(powerPercent: number?, powerResult: string?): number
	local rollConfig = getRollConfig(self.Framework)
	local powerBonus = tonumber(rollConfig.PowerLuckBonus) or DEFAULT_POWER_LUCK_BONUS

	return powerBonus * getTimingWeight(powerPercent or 0, powerResult)
end

function MicrowaveService:GetCookLuck(baseLuck: number, powerPercent: number?, powerResult: string?): number
	return math.max(0, baseLuck + self:GetTimingLuckBonus(powerPercent, powerResult))
end

function MicrowaveService:GetFinalLuck(baseLuck: number, powerPercent: number?, powerResult: string?): number
	return math.max(0, baseLuck + self:GetTimingLuckBonus(powerPercent, powerResult))
end

function MicrowaveService:GetBrainrotPool(luck: number)
	local brainrotConfig = self.Framework.Config.Brainrots or {}
	local rollConfig = getRollConfig(self.Framework)
	local activePool = self:GetLuckPool(luck)
	local activeRarities = {}
	if activePool and type(activePool.Rarities) == 'table' then
		for _, rarityEntry in ipairs(activePool.Rarities) do
			activeRarities[tostring(rarityEntry.Name)] = true
		end
	end
	local rarityOrder = rollConfig.RarityOrder or {}
	local pool = {}

	for rewardName, config in pairs(brainrotConfig) do
		if type(config) == 'table' and findBrainrotTemplate(rewardName, config) then
			local rarity = tostring(config.Rarity or 'Common')
			if not activePool or activeRarities[rarity] then
				local baseWeight = tonumber(config.RollWeight or config.BaseWeight or config.Weight) or 100
				table.insert(pool, {
					Name = rewardName,
					ModelName = tostring(config.ModelName or rewardName),
					Rarity = rarity,
					BaseIncome = tonumber(config.BaseIncome),
					Weight = math.max(0, baseWeight),
					Rank = tonumber(rarityOrder[rarity]) or 1,
				})
			end
		end
	end

	table.sort(pool, function(a, b)
		if a.Rank == b.Rank then
			return a.Name < b.Name
		end
		return a.Rank < b.Rank
	end)
	return pool
end

function MicrowaveService:GetLuckPool(luck: number)
	local luckPoolConfig = self.Framework.Config.LuckPool or {}
	for _, pool in ipairs(luckPoolConfig.Pools or {}) do
		local minLuck = tonumber(pool.MinLuck) or 0
		local maxLuck = tonumber(pool.MaxLuck) or math.huge
		if luck >= minLuck and luck <= maxLuck then
			return pool
		end
	end
	return nil
end

function MicrowaveService:GetLuckPoolQuality(luck: number, pool): number
	if not pool then
		return 0
	end

	local minLuck = tonumber(pool.MinLuck) or 0
	local maxLuck = tonumber(pool.MaxLuck) or minLuck
	if maxLuck == math.huge or maxLuck <= minLuck then
		return 0
	end
	return math.clamp((luck - minLuck) / (maxLuck - minLuck), 0, 1)
end

function MicrowaveService:RollWeightedEntry(pool)
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += entry.Weight
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = self.Random:NextNumber(0, totalWeight)
	local cursor = 0
	for _, entry in ipairs(pool) do
		cursor += entry.Weight
		if roll <= cursor then
			return entry
		end
	end

	return pool[#pool]
end

function MicrowaveService:RollRarity(luck: number): string?
	local luckPoolConfig = self.Framework.Config.LuckPool or {}
	local activePool = self:GetLuckPool(luck)
	if not activePool or type(activePool.Rarities) ~= 'table' then
		return nil
	end

	local quality = self:GetLuckPoolQuality(luck, activePool)
	local overflowBonus = tonumber(luckPoolConfig.OverflowQualityBonus) or 0
	local positionPower = luckPoolConfig.PositionPower or {}
	local rarityPool = {}

	for _, rarityEntry in ipairs(activePool.Rarities) do
		local position = tostring(rarityEntry.Position or 'Mid')
		local power = tonumber(positionPower[position]) or 0
		local multiplier = (1 + quality * overflowBonus) ^ power
		table.insert(rarityPool, {
			Name = tostring(rarityEntry.Name),
			Weight = math.max(0, (tonumber(rarityEntry.Weight) or 0) * multiplier),
		})
	end

	local entry = self:RollWeightedEntry(rarityPool)
	return entry and entry.Name or nil
end

function MicrowaveService:RollBrainrot(luck: number)
	local rarity = self:RollRarity(luck)
	local pool = {}

	for _, entry in ipairs(self:GetBrainrotPool(luck)) do
		if not rarity or entry.Rarity == rarity then
			table.insert(pool, entry)
		end
	end

	local rolled = self:RollWeightedEntry(pool)
	if rolled then
		return rolled
	end

	local fallbackName = self:GetRewardName()
	local fallbackConfig = (self.Framework.Config.Brainrots or {})[fallbackName] or {}
	return {
		Name = fallbackName,
		ModelName = fallbackConfig.ModelName or fallbackName,
		Rarity = fallbackConfig.Rarity or 'Common',
		BaseIncome = tonumber(fallbackConfig.BaseIncome),
		Weight = 1,
		Rank = 1,
	}
end

function MicrowaveService:GetMutationPool(luck: number)
	local mutationConfig = self.Framework.Config.Mutations or {}
	local mutations = mutationConfig.Mutations or {}
	local mutationLuck = math.max(tonumber(mutationConfig.DefaultMutationLuck) or 1, tonumber(luck) or 0)
	local pool = {}

	for mutationName, config in pairs(mutations) do
		if type(config) == 'table' then
			local baseWeight = tonumber(config.BaseWeight) or 0
			local luckPower = tonumber(config.LuckPower) or 0
			table.insert(pool, {
				Name = tostring(mutationName),
				DisplayName = tostring(config.DisplayName or mutationName),
				Multiplier = tonumber(config.Multiplier) or 1,
				IsMutation = config.IsMutation == true,
				Weight = math.max(0, baseWeight * (mutationLuck ^ luckPower)),
			})
		end
	end

	table.sort(pool, function(a, b)
		return a.Name < b.Name
	end)
	return pool
end

function MicrowaveService:RollMutation(luck: number)
	local rolled = self:RollWeightedEntry(self:GetMutationPool(luck))
	if rolled then
		return rolled
	end

	return {
		Name = DEFAULT_MUTATION,
		DisplayName = DEFAULT_MUTATION,
		Multiplier = 1,
		IsMutation = false,
		Weight = 1,
	}
end

function MicrowaveService:GetPreviewEntry(pool, usedNames, startIndex: number, blockedName: string?)
	if #pool == 0 then
		return nil
	end

	for offset = 0, #pool - 1 do
		local entry = pool[((startIndex + offset - 1) % #pool) + 1]
		if entry.Name ~= blockedName and not usedNames[entry.Name] then
			usedNames[entry.Name] = true
			return entry
		end
	end

	table.clear(usedNames)
	if blockedName then
		usedNames[blockedName] = true
	end
	local entry = pool[((startIndex - 1) % #pool) + 1]
	if entry.Name == blockedName then
		return nil
	end
	usedNames[entry.Name] = true
	return entry
end

function MicrowaveService:BuildRollPreview(luck: number, reward)
	local rollConfig = getRollConfig(self.Framework)
	local previewCount = math.clamp(math.floor(tonumber(rollConfig.PreviewCount) or DEFAULT_PREVIEW_COUNT), 6, 36)
	local preview = {}
	local pool = self:GetBrainrotPool(luck)
	local usedNames = {}
	if reward and reward.Name then
		usedNames[reward.Name] = true
	end
	local cursor = self.Random:NextInteger(1, math.max(1, #pool))

	for _ = 1, previewCount - 1 do
		cursor += self.Random:NextInteger(2, math.max(2, math.floor(#pool / 3)))
		local entry = self:GetPreviewEntry(pool, usedNames, cursor, reward.Name) or self:RollBrainrot(luck)
		if entry.Name == reward.Name then
			entry = self:GetPreviewEntry(pool, usedNames, cursor + 1, reward.Name) or entry
		end
		local mutation = self:RollMutation(luck)
		table.insert(preview, {
			Name = entry.Name,
			ModelName = entry.ModelName,
			Rarity = entry.Rarity,
			Mutation = mutation.Name,
			BaseIncome = (tonumber(entry.BaseIncome) or 0) * (tonumber(mutation.Multiplier) or 1),
		})
	end

	table.insert(preview, {
		Name = reward.Name,
		ModelName = reward.ModelName,
		Rarity = reward.Rarity,
		Mutation = reward.Mutation or DEFAULT_MUTATION,
		BaseIncome = reward.BaseIncome,
		Winner = true,
	})
	return preview
end

function MicrowaveService:GetMicrowaveConfig(_microwave: Model)
	local minigameConfig = getMicrowaveMinigameConfig(self.Framework)
	local okayThreshold = math.clamp(tonumber(minigameConfig.OkayThreshold) or DEFAULT_OKAY_THRESHOLD, 0, 1)
	local perfectThreshold = math.clamp(tonumber(minigameConfig.PerfectThreshold) or DEFAULT_PERFECT_THRESHOLD, okayThreshold, 1)
	return {
		CookTime = math.clamp(tonumber(minigameConfig.CookTime) or DEFAULT_COOK_TIME, 1, 30),
		StopReadyPadding = math.clamp(tonumber(minigameConfig.StopReadyPadding) or DEFAULT_STOP_READY_PADDING, 0, 2),
		OkayThreshold = okayThreshold,
		PerfectThreshold = perfectThreshold,
		SetPowerSpeed = math.clamp(tonumber(minigameConfig.SetPowerSpeed) or DEFAULT_SET_POWER_SPEED, 0.25, 6),
		StopMicrowaveSpeed = math.clamp(tonumber(minigameConfig.StopMicrowaveSpeed) or DEFAULT_STOP_MICROWAVE_SPEED, 0.25, 6),
	}
end

function MicrowaveService:GetFolder(microwave: Model, folderName: string): Folder
	local folder = microwave:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new('Folder')
		folder.Name = folderName
		folder.Parent = microwave
	end
	return folder :: Folder
end

function MicrowaveService:ClearFolder(microwave: Model, folderName: string)
	local folder = microwave:FindFirstChild(folderName)
	if folder then
		folder:ClearAllChildren()
	end
end

function MicrowaveService:SpawnReward(session): Model?
	local microwave = session.Microwave
	if not microwave or not microwave:IsA('Model') then
		return nil
	end

	local luck = tonumber(session.FinalLuck) or tonumber(session.Luck) or 1
	local rolledReward = self:RollBrainrot(luck)
	local rolledMutation = self:RollMutation(luck)
	local rewardName = rolledReward.Name
	local rewardModelName = rolledReward.ModelName or rewardName
	local rewardConfig = (self.Framework.Config.Brainrots or {})[rewardName] or {}
	local mutationMultiplier = tonumber(rolledMutation.Multiplier) or 1
	local baseIncome = tonumber(rolledReward.BaseIncome) or tonumber(rewardConfig.BaseIncome) or 1
	local moneyPerSecond = baseIncome * mutationMultiplier
	local template = findBrainrotTemplate(rewardName, rewardConfig, rolledMutation.Name)
	if not template or not template:IsA('Model') then
		warn(('[MicrowaveService] Missing brainrot reward model for %s. Expected ReplicatedStorage.Assets.Brainrots.%s.%s.%s, with Normal fallback'):format(
			rewardName,
			tostring(rolledMutation.Name or DEFAULT_MUTATION),
			tostring(rewardConfig.Rarity or '?'),
			tostring(rewardConfig.ModelName or rewardName)
		))
		return nil
	end

	local config = getMicrowaveConfig(self.Framework)
	self:ClearFolder(microwave, config.SessionBlockFolderName or DEFAULT_SESSION_BLOCK_FOLDER_NAME)
	local folder = self:GetFolder(microwave, config.ResultFolderName or DEFAULT_RESULT_FOLDER_NAME)
	folder:ClearAllChildren()

	local reward = template:Clone()
	reward.Name = rewardModelName
	reward:SetAttribute('ItemType', 'Brainrot')
	reward:SetAttribute('Rarity', tostring(rolledReward.Rarity or 'Common'))
	reward:SetAttribute('Mutation', tostring(rolledMutation.Name or DEFAULT_MUTATION))
	reward:SetAttribute('BaseIncome', baseIncome)
	reward:SetAttribute('MoneyPerSecond', moneyPerSecond)
	prepResultModel(reward)
	session.RewardName = rewardName
	session.RewardModelName = rewardModelName
	session.RewardRarity = tostring(rolledReward.Rarity or 'Common')
	session.RewardMutation = tostring(rolledMutation.Name or DEFAULT_MUTATION)
	session.RollPreview = self:BuildRollPreview(luck, {
		Name = rewardName,
		ModelName = rewardModelName,
		Rarity = session.RewardRarity,
		Mutation = session.RewardMutation,
		BaseIncome = moneyPerSecond,
	})
	session.RewardModel = reward
	return reward
end

function MicrowaveService:InsertLuckyblock(microwave: Model, prompt: ProximityPrompt, luckyblock: Model): BasePart
	local config = getMicrowaveConfig(self.Framework)
	local folder = self:GetFolder(microwave, config.SessionBlockFolderName or DEFAULT_SESSION_BLOCK_FOLDER_NAME)
	folder:ClearAllChildren()
	self:ClearFolder(microwave, config.ResultFolderName or DEFAULT_RESULT_FOLDER_NAME)

	prepInsertedBlock(luckyblock)
	luckyblock.Parent = folder

	local slot = self:GetOrCreateSlot(microwave, prompt)
	local _, size = luckyblock:GetBoundingBox()
	luckyblock:PivotTo(slot.CFrame * CFrame.new(0, size.Y * 0.5, 0))
	return slot
end

function MicrowaveService:CanStartOpening(player: Player, prompt: Instance)
	local activeSession = self.ActiveSessions[player]
	if activeSession then
		local staleAfter = (tonumber(activeSession.CookTime) or DEFAULT_COOK_TIME) + 20
		if os.clock() - (tonumber(activeSession.StartTime) or 0) > staleAfter then
			warn(('[MicrowaveService] Auto-clearing stale microwave session for %s in phase %s'):format(player.Name, tostring(activeSession.Phase)))
			self:ResolveActiveSession(player)
		else
			return false, nil, 'Busy'
		end
	end

	local config = getMicrowaveConfig(self.Framework)
	if not prompt or not prompt:IsA('ProximityPrompt') or prompt.Name ~= (config.PromptName or DEFAULT_MICROWAVE_PROMPT_NAME) then
		return false, nil, 'InvalidPrompt'
	end

	if not self:IsPlayerNearPrompt(player, prompt) then
		return false, nil, 'TooFar'
	end

	local base = self:GetBaseForPrompt(prompt)
	if not base or base.Owner ~= player then
		return false, nil, 'WrongOwner'
	end

	local microwave = findAncestorModel(prompt, config.ModelName or DEFAULT_MICROWAVE_MODEL_NAME)
	if not microwave then
		return false, nil, 'MissingMicrowave'
	end

	return true, microwave
end

function MicrowaveService:StartOpening(player: Player, prompt: Instance)
	local canStart, microwave, reason = self:CanStartOpening(player, prompt)
	if not canStart or not microwave then
		return { Ok = false, Reason = reason or 'Rejected' }
	end

	local inventoryService = self.Framework:GetService('InventoryService')
	if inventoryService.SetInventoryLocked then
		inventoryService:SetInventoryLocked(player, true)
	end

	local luckyblock, luckyblockName = inventoryService:TakeEquippedItem(player, 'Luckyblock')
	if not luckyblock then
		if inventoryService.SetInventoryLocked then
			inventoryService:SetInventoryLocked(player, false)
		end
		return { Ok = false, Reason = 'NoLuckyblock' }
	end

	local microwavePrompt = prompt :: ProximityPrompt
	microwavePrompt.Enabled = false
	local luckyblockLuck = self:GetLuckyblockLuck(luckyblock, luckyblockName)
	local slot = self:InsertLuckyblock(microwave, microwavePrompt, luckyblock)
	local config = self:GetMicrowaveConfig(microwave)

	local session = {
		Ok = true,
		StartTime = os.clock(),
		Phase = 'SetPower',
		LuckyblockName = luckyblockName,
		LuckyblockModel = luckyblock,
		Luck = luckyblockLuck,
		Microwave = microwave,
		Prompt = microwavePrompt,
		Slot = slot,
		CookTime = config.CookTime,
		StopReadyPadding = config.StopReadyPadding,
		OkayThreshold = config.OkayThreshold,
		PerfectThreshold = config.PerfectThreshold,
		SetPowerSpeed = config.SetPowerSpeed,
		StopMicrowaveSpeed = config.StopMicrowaveSpeed,
	}

	self.ActiveSessions[player] = session
	task.delay(session.CookTime + 20, function()
		if self.ActiveSessions[player] == session then
			warn(('[MicrowaveService] Auto-resolving stale microwave session for %s in phase %s'):format(player.Name, tostring(session.Phase)))
			self:ResolveActiveSession(player)
		end
	end)
	self.Framework:GetController('MicrowaveController').Server.Fire:ShowSetPower(player, session)
	return session
end

function MicrowaveService.Client:StartOpening(player: Player, prompt: Instance)
	return self:StartOpening(player, prompt)
end

function MicrowaveService:SetPower(player: Player, percent: number)
	local session = self.ActiveSessions[player]
	if not session or session.Phase ~= 'SetPower' or type(percent) ~= 'number' then
		return { Ok = false }
	end

	percent = math.clamp(percent, 0, 1)
	session.PowerPercent = percent
	session.PowerResult = getTimingResult(percent, session.PerfectThreshold, session.OkayThreshold)
	session.CookLuck = self:GetCookLuck(session.Luck, session.PowerPercent, session.PowerResult)
	session.Phase = 'Cooking'
	session.CookingStartTime = os.clock()

	return {
		Ok = true,
		Phase = session.Phase,
		PowerPercent = session.PowerPercent,
		PowerResult = session.PowerResult,
	}
end

function MicrowaveService.Client:SetPower(player: Player, percent: number)
	return self:SetPower(player, percent)
end

function MicrowaveService:BeginStop(player: Player)
	local session = self.ActiveSessions[player]
	if not session or session.Phase ~= 'Cooking' or type(session.CookingStartTime) ~= 'number' then
		return { Ok = false }
	end

	if os.clock() - session.CookingStartTime < session.CookTime - session.StopReadyPadding then
		return { Ok = false }
	end

	session.Phase = 'StopMicrowave'
	session.StopStartTime = os.clock()

	return {
		Ok = true,
		Phase = session.Phase,
	}
end

function MicrowaveService.Client:BeginStop(player: Player)
	return self:BeginStop(player)
end

function MicrowaveService:StopMicrowave(player: Player, percent: number)
	local session = self.ActiveSessions[player]
	if not session or session.Phase ~= 'StopMicrowave' or type(percent) ~= 'number' then
		return { Ok = false }
	end

	percent = math.clamp(percent, 0, 1)
	session.StopPercent = percent
	session.StopResult = getTimingResult(percent, session.PerfectThreshold, session.OkayThreshold)
	session.FinalLuck = self:GetFinalLuck(session.Luck, session.PowerPercent, session.PowerResult)
	session.Phase = 'Revealing'
	local reward = self:SpawnReward(session)
	if not reward then
		self:CleanupSession(player, true)
		return { Ok = false, Cancelled = true }
	end

	return {
		Ok = true,
		Phase = session.Phase,
		StopPercent = session.StopPercent,
		StopResult = session.StopResult,
		PowerPercent = session.PowerPercent,
		PowerResult = session.PowerResult,
		RewardName = session.RewardName,
		RewardRarity = session.RewardRarity,
		RewardMutation = session.RewardMutation,
		RollPreview = session.RollPreview,
	}
end

function MicrowaveService.Client:StopMicrowave(player: Player, percent: number)
	return self:StopMicrowave(player, percent)
end

function MicrowaveService:FinishMicrowave(player: Player)
	local session = self.ActiveSessions[player]
	if not session then
		return { Ok = false }
	end

	if session.Phase ~= 'Revealing' then
		self:CleanupSession(player, true)
		return { Ok = false, Cancelled = true }
	end

	if session.RewardModel and session.RewardModel:IsA('Model') then
		local inventoryService = self.Framework:GetService('InventoryService')
		inventoryService:AddItem(player, session.RewardModel, 'Brainrot', session.RewardName)
	end

	self:CleanupSession(player, false)
	return {
		Ok = true,
		RewardName = session.RewardName,
		RewardRarity = session.RewardRarity,
		RewardMutation = session.RewardMutation,
	}
end

function MicrowaveService.Client:FinishMicrowave(player: Player)
	return self:FinishMicrowave(player)
end

return MicrowaveService
