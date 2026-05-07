local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local CombatDefinitions = require(script.Parent.CombatDefinitions)

local CombatAnimations = {}

local animationIdCache = setmetatable({}, { __mode = "k" })

local function normalizeAnimationId(value: string)
	return value
end

function CombatAnimations.GetAnimationIdFromSequence(sequence: KeyframeSequence)
	local cached = animationIdCache[sequence]
	if cached then
		return cached
	end

	local success, registeredId = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	assert(success and type(registeredId) == "string", ("Failed to register combat sequence %s"):format(sequence:GetFullName()))

	cached = normalizeAnimationId(registeredId)
	animationIdCache[sequence] = cached
	return cached
end

function CombatAnimations.GetAnimationIdFromPath(sequencePath: string)
	local sequence = CombatDefinitions.ResolveSequence(sequencePath)
	return CombatAnimations.GetAnimationIdFromSequence(sequence)
end

function CombatAnimations.CreateAnimation(animationId: string, animationName: string?)
	local animation = Instance.new("Animation")
	animation.Name = animationName or "CombatAnimation"
	animation.AnimationId = normalizeAnimationId(animationId)
	return animation
end

function CombatAnimations.CreateAnimationFromPath(sequencePath: string)
	return CombatAnimations.CreateAnimation(
		CombatAnimations.GetAnimationIdFromPath(sequencePath),
		sequencePath:match("[^%.]+$") or "CombatAnimation"
	)
end

return table.freeze(CombatAnimations)
