local ReplicatedStorage = game:GetService('ReplicatedStorage')
local KeyframeSequenceProvider = game:GetService('KeyframeSequenceProvider')
local Players = game:GetService('Players')
local InventoryItemClient = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('InventoryItemClient', true) :: ModuleScript)

local LuckyblockClient = InventoryItemClient:Extend('LuckyblockClient')

local DEFAULT_MICROWAVE_PROMPT_NAME = 'MicrowavePrompt'
local DEFAULT_HOLD_ANIMATION_NAMES = {
	'HoldingLuckyblock',
	'LuckyblockHolding',
	'LuckyblockHold',
	'HoldLuckyblock',
}
local DEFAULT_HOLD_ANIMATION_ATTRIBUTE = 'HoldAnimationId'
local HOLD_ANIMATION_PRIORITY = Enum.AnimationPriority.Action

local equippedLuckyblockCount = 0
local promptWatcherBound = false
local missingAnimationWarned = false
local microwavePrompts = {}
local animationById = {}
local animationBySource = setmetatable({}, { __mode = 'k' })
local tracksByAnimator = setmetatable({}, { __mode = 'k' })
local holdingAnimationSourceByKey = {}

local function getMicrowavePromptName(framework): string
	return (framework and framework.Config and framework.Config.Microwave and framework.Config.Microwave.PromptName) or DEFAULT_MICROWAVE_PROMPT_NAME
end

local function isMicrowavePrompt(instance: Instance, promptName: string): boolean
	return instance:IsA('ProximityPrompt') and instance.Name == promptName
end

local function setPromptEnabled(prompt: ProximityPrompt)
	prompt.Enabled = equippedLuckyblockCount > 0
end

local function refreshMicrowavePrompts(promptName: string)
	for index = #microwavePrompts, 1, -1 do
		local prompt = microwavePrompts[index]
		if not prompt.Parent then
			table.remove(microwavePrompts, index)
		elseif isMicrowavePrompt(prompt, promptName) then
			setPromptEnabled(prompt :: ProximityPrompt)
		end
	end
end

local function bindPromptWatcher(promptName: string)
	if promptWatcherBound then
		return
	end
	promptWatcherBound = true

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if isMicrowavePrompt(descendant, promptName) then
			table.insert(microwavePrompts, descendant :: ProximityPrompt)
			setPromptEnabled(descendant :: ProximityPrompt)
		end
	end

	workspace.DescendantAdded:Connect(function(descendant)
		if isMicrowavePrompt(descendant, promptName) then
			table.insert(microwavePrompts, descendant :: ProximityPrompt)
			setPromptEnabled(descendant :: ProximityPrompt)
		end
	end)
end

local function getInventoryConfig(framework)
	return (framework and framework.Config and framework.Config.Inventory) or {}
end

local function getLuckyblockHoldConfig(framework)
	local inventoryConfig = getInventoryConfig(framework)
	return inventoryConfig.LuckyblockHold or {}
end

local function getAnimationNames(holdConfig)
	return holdConfig.AnimationNames or DEFAULT_HOLD_ANIMATION_NAMES
end

local function getAnimationCacheKey(animationNames): string
	return table.concat(animationNames, '\0')
end

local function normalizeAnimationId(value: string): string
	if value:match('^rbxassetid://') then
		return value
	end

	if value:match('^%d+$') then
		return 'rbxassetid://' .. value
	end

	return value
end

local function getCharacter(model: Model?): Model?
	local parent = model and model.Parent
	return if parent and parent:IsA('Model') then parent else nil
end

local function getAnimator(character: Model?): Animator?
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass('Humanoid')
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass('Animator')
	if not animator then
		animator = Instance.new('Animator')
		animator.Parent = humanoid
	end

	return animator
end

local function findAnimationInRoot(root: Instance?, animationNames, recursive: boolean): Instance?
	if not root then
		return nil
	end

	for _, animationName in ipairs(animationNames) do
		local animation = root:FindFirstChild(animationName, recursive)
		if animation and (animation:IsA('Animation') or animation:IsA('KeyframeSequence')) then
			return animation
		end
	end

	return nil
end

local function findHoldingAnimationSource(holdConfig): Instance?
	local animationNames = getAnimationNames(holdConfig)
	local cacheKey = getAnimationCacheKey(animationNames)
	local cached = holdingAnimationSourceByKey[cacheKey]
	if cached ~= nil then
		return if cached == false then nil else cached
	end

	local assets = ReplicatedStorage:FindFirstChild('Assets')
	local animations = assets and assets:FindFirstChild('Animations')
	local source = findAnimationInRoot(animations, animationNames, false)
		or findAnimationInRoot(assets, animationNames, false)
		or findAnimationInRoot(ReplicatedStorage, animationNames, false)
		or findAnimationInRoot(ReplicatedStorage, animationNames, true)

	holdingAnimationSourceByKey[cacheKey] = source or false
	return source
end

local function createHoldingAnimation(model: Model?, holdConfig): Animation?
	local animationAttribute = holdConfig.AnimationIdAttribute or DEFAULT_HOLD_ANIMATION_ATTRIBUTE
	local animationId = model and model:GetAttribute(animationAttribute)
	if type(animationId) == 'string' and animationId ~= '' then
		local normalizedId = normalizeAnimationId(animationId)
		if not animationById[normalizedId] then
			local animation = Instance.new('Animation')
			animation.Name = 'LuckyblockHold'
			animation.AnimationId = normalizedId
			animationById[normalizedId] = animation
		end
		return animationById[normalizedId]
	end

	local source = findHoldingAnimationSource(holdConfig)
	if source and source:IsA('Animation') then
		return source
	end

	if source and source:IsA('KeyframeSequence') then
		if animationBySource[source] then
			return animationBySource[source]
		end

		local ok, registeredId = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(source)
		end)
		if ok and type(registeredId) == 'string' then
			local animation = Instance.new('Animation')
			animation.Name = source.Name
			animation.AnimationId = normalizeAnimationId(registeredId)
			animationBySource[source] = animation
			return animation
		end
	end

	return nil
end

function LuckyblockClient:Create(model: Model, slot: number, itemType: string)
	InventoryItemClient.Create(self, model, slot, itemType)
	self.MicrowavePromptName = getMicrowavePromptName(self.Framework)
	self.HoldAnimation = createHoldingAnimation(model, getLuckyblockHoldConfig(self.Framework))
	bindPromptWatcher(self.MicrowavePromptName)
	self:RefreshLuckyblock()
	refreshMicrowavePrompts(self.MicrowavePromptName)
end

function LuckyblockClient:SetModel(model: Model)
	if self.Model == model then
		return
	end

	InventoryItemClient.SetModel(self, model)
	self.HoldAnimation = createHoldingAnimation(model, getLuckyblockHoldConfig(self.Framework))
	self:RefreshLuckyblock()
	self:RefreshHoldAnimation()
end

function LuckyblockClient:SetEquipped(equipped: boolean)
	local wasEquipped = self.Equipped == true
	InventoryItemClient.SetEquipped(self, equipped)

	if wasEquipped == self.Equipped then
		return
	end

	equippedLuckyblockCount += if self.Equipped then 1 else -1
	equippedLuckyblockCount = math.max(equippedLuckyblockCount, 0)
	if self.Equipped or equippedLuckyblockCount == 0 then
		self:RefreshHoldAnimation()
	else
		self.HoldAnimationTrack = nil
	end
	refreshMicrowavePrompts(self.MicrowavePromptName or getMicrowavePromptName(self.Framework))
end

function LuckyblockClient:RefreshLuckyblock()
	self.LuckyblockName = self.Model.Name
end

function LuckyblockClient:StopHoldAnimation()
	if self.HoldAnimationTrack then
		self.HoldAnimationTrack:Stop(0.15)
		self.HoldAnimationTrack = nil
	end
end

local function getHoldTrack(animator: Animator, animation: Animation): AnimationTrack
	local tracksByAnimation = tracksByAnimator[animator]
	if not tracksByAnimation then
		tracksByAnimation = setmetatable({}, { __mode = 'k' })
		tracksByAnimator[animator] = tracksByAnimation
	end

	local track = tracksByAnimation[animation]
	if not track then
		track = animator:LoadAnimation(animation)
		track.Priority = HOLD_ANIMATION_PRIORITY
		track.Looped = true
		tracksByAnimation[animation] = track
	end

	return track
end

function LuckyblockClient:PlayHoldAnimation()
	if self.HoldAnimationTrack and self.HoldAnimationTrack.IsPlaying then
		return
	end

	local animator = getAnimator(getCharacter(self.Model) or (Players.LocalPlayer and Players.LocalPlayer.Character))
	if not animator then
		return
	end

	local animation = self.HoldAnimation or createHoldingAnimation(self.Model, getLuckyblockHoldConfig(self.Framework))
	self.HoldAnimation = animation
	if not animation then
		if not missingAnimationWarned then
			missingAnimationWarned = true
			warn('[LuckyblockClient] Missing holding animation. Add an Animation or KeyframeSequence named HoldingLuckyblock, LuckyblockHolding, LuckyblockHold, or HoldLuckyblock under ReplicatedStorage, or set HoldAnimationId on the luckyblock model.')
		end
		return
	end

	self:StopHoldAnimation()

	local track = getHoldTrack(animator, animation)
	track:Play(0.15)
	self.HoldAnimationTrack = track
end

function LuckyblockClient:RefreshHoldAnimation()
	if self.Equipped then
		self:PlayHoldAnimation()
	else
		self:StopHoldAnimation()
	end
end

function LuckyblockClient:CleanUp()
	if self.Equipped then
		equippedLuckyblockCount = math.max(equippedLuckyblockCount - 1, 0)
		if equippedLuckyblockCount == 0 then
			self:StopHoldAnimation()
		else
			self.HoldAnimationTrack = nil
		end
		refreshMicrowavePrompts(self.MicrowavePromptName or getMicrowavePromptName(self.Framework))
	else
		self:StopHoldAnimation()
	end
end

return LuckyblockClient
