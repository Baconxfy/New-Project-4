local CombatMarkers = require(script.Parent.CombatMarkers)

local CombatDefinitions = {}

local moveDefinitions = {
	Light1 = {
		Id = "Light1",
		DisplayName = "Light 1",
		ActionType = "Attack",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Attacks.Light1",
		Trace = {
			Range = 7,
			Width = 5,
			Height = 4,
			MaxTargets = 3,
		},
		Markers = {
			[CombatMarkers.WindupStart] = 0.000,
			[CombatMarkers.TrailOn] = 0.183,
			[CombatMarkers.ActiveStart] = 0.233,
			[CombatMarkers.Contact] = 0.267,
			[CombatMarkers.ActiveEnd] = 0.333,
			[CombatMarkers.ComboBufferOpen] = 0.367,
			[CombatMarkers.TrailOff] = 0.367,
			[CombatMarkers.RecoverEnd] = 0.517,
		},
		NextMoves = { "Light2" },
		ComboOnHitOnly = true,
		Damage = 10,
		PostureDamage = 16,
		LinkConfirmWindow = 0.04,
		DesiredBlockAdvantage = -0.08,
		ChipDamageMultiplier = 0.1,
		GuardDamage = 18,
		ReactionId = "Hit1",
		SoftConfirmHitstop = 0.035,
		WhiffLockDuration = 0.08,
		BlockedRecoveryLock = 0.03,
	},
	Light2 = {
		Id = "Light2",
		DisplayName = "Light 2",
		ActionType = "Attack",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Attacks.Light2",
		Trace = {
			Range = 7.5,
			Width = 5,
			Height = 4,
			MaxTargets = 3,
		},
		Markers = {
			[CombatMarkers.WindupStart] = 0.000,
			[CombatMarkers.TrailOn] = 0.300,
			[CombatMarkers.ActiveStart] = 0.333,
			[CombatMarkers.Contact] = 0.367,
			[CombatMarkers.ActiveEnd] = 0.417,
			[CombatMarkers.ComboBufferOpen] = 0.417,
			[CombatMarkers.TrailOff] = 0.467,
			[CombatMarkers.RecoverEnd] = 0.517,
		},
		NextMoves = { "Light3" },
		ComboOnHitOnly = true,
		Damage = 10,
		PostureDamage = 18,
		LinkConfirmWindow = 0.04,
		DesiredBlockAdvantage = -0.1,
		ChipDamageMultiplier = 0.1,
		GuardDamage = 20,
		ReactionId = "Hit2",
		SoftConfirmHitstop = 0.04,
		WhiffLockDuration = 0.09,
		BlockedRecoveryLock = 0.04,
	},
	Light3 = {
		Id = "Light3",
		DisplayName = "Light 3",
		ActionType = "Attack",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Attacks.Light3",
		Trace = {
			Range = 8,
			Width = 5.5,
			Height = 4,
			MaxTargets = 3,
		},
		Markers = {
			[CombatMarkers.WindupStart] = 0.000,
			[CombatMarkers.TrailOn] = 0.300,
			[CombatMarkers.ActiveStart] = 0.333,
			[CombatMarkers.Contact] = 0.367,
			[CombatMarkers.ActiveEnd] = 0.417,
			[CombatMarkers.ComboBufferOpen] = 0.467,
			[CombatMarkers.TrailOff] = 0.467,
			[CombatMarkers.RecoverEnd] = 0.650,
		},
		NextMoves = { "Light4" },
		ComboOnHitOnly = true,
		Damage = 12,
		PostureDamage = 22,
		LinkConfirmWindow = 0.05,
		DesiredBlockAdvantage = -0.12,
		ChipDamageMultiplier = 0.12,
		GuardDamage = 24,
		ReactionId = "Hit3",
		SoftConfirmHitstop = 0.045,
		WhiffLockDuration = 0.11,
		BlockedRecoveryLock = 0.05,
	},
	Light4 = {
		Id = "Light4",
		DisplayName = "Light 4",
		ActionType = "Attack",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Attacks.Light4",
		Trace = {
			Range = 8.5,
			Width = 6,
			Height = 4.5,
			MaxTargets = 4,
		},
		Markers = {
			[CombatMarkers.WindupStart] = 0.000,
			[CombatMarkers.TrailOn] = 0.350,
			[CombatMarkers.ActiveStart] = 0.383,
			[CombatMarkers.Contact] = 0.417,
			[CombatMarkers.ActiveEnd] = 0.500,
			[CombatMarkers.ComboBufferOpen] = 0.500,
			[CombatMarkers.TrailOff] = 0.500,
			[CombatMarkers.RecoverEnd] = 0.833,
		},
		NextMoves = {},
		Damage = 14,
		PostureDamage = 28,
		DesiredHitAdvantage = 0.1,
		DesiredBlockAdvantage = -0.22,
		ChipDamageMultiplier = 0.12,
		GuardDamage = 28,
		ReactionId = "Hit4",
		SoftConfirmHitstop = 0.05,
		WhiffLockDuration = 0.14,
		BlockedRecoveryLock = 0.06,
	},
	Heavy1 = {
		Id = "Heavy1",
		DisplayName = "Heavy 1",
		ActionType = "Attack",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Attacks.Heavy1",
		Trace = {
			Range = 9,
			Width = 6,
			Height = 4.5,
			MaxTargets = 5,
		},
		Markers = {
			[CombatMarkers.WindupStart] = 0.000,
			[CombatMarkers.TrailOn] = 0.500,
			[CombatMarkers.ActiveStart] = 0.533,
			[CombatMarkers.Contact] = 0.567,
			[CombatMarkers.ActiveEnd] = 0.633,
			[CombatMarkers.TrailOff] = 0.667,
			[CombatMarkers.RecoverEnd] = 0.917,
		},
		NextMoves = {},
		Damage = 20,
		PostureDamage = 40,
		DesiredHitAdvantage = 0.18,
		DesiredBlockAdvantage = -0.28,
		ChipDamageMultiplier = 0.2,
		GuardDamage = 40,
		ReactionId = "Hit4",
		SoftConfirmHitstop = 0.06,
		WhiffLockDuration = 0.2,
		BlockedRecoveryLock = 0.12,
	},
	Block = {
		Id = "Block",
		DisplayName = "Block",
		ActionType = "Defense",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Defense.Block",
		Markers = {
			[CombatMarkers.GuardStart] = 0.000,
			[CombatMarkers.GuardActiveStart] = 0.150,
			[CombatMarkers.RecoverEnd] = 0.250,
		},
		Holdable = true,
		BlockAngleDotMin = 0.2,
		GuardMeterMax = 100,
		GuardRecoveryDelay = 1.25,
		GuardRecoveryPerSecond = 18,
		BreakDuration = 1.25,
		PostureMax = 100,
		PostureRecoveryDelay = 1.2,
		PostureRecoveryPerSecond = 16,
		StaggerDuration = 0.7,
		NextMoves = {},
	},
	Parry = {
		Id = "Parry",
		DisplayName = "Parry",
		ActionType = "Defense",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Defense.Parry",
		Markers = {
			[CombatMarkers.ParryStart] = 0.000,
			[CombatMarkers.ParryActiveStart] = 0.100,
			[CombatMarkers.ParryActiveEnd] = 0.183,
			[CombatMarkers.RecoverEnd] = 0.450,
		},
		NextMoves = {},
	},
}

local reactionDefinitions = {
	Hit1 = {
		Id = "Hit1",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Reactions.Hit1",
		Markers = {
			[CombatMarkers.HitReactStart] = 0.000,
			[CombatMarkers.HitReactPeak] = 0.150,
			[CombatMarkers.RecoverEnd] = 0.833,
		},
	},
	Hit2 = {
		Id = "Hit2",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Reactions.Hit2",
		Markers = {
			[CombatMarkers.HitReactStart] = 0.000,
			[CombatMarkers.HitReactPeak] = 0.150,
			[CombatMarkers.RecoverEnd] = 0.833,
		},
	},
	Hit3 = {
		Id = "Hit3",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Reactions.Hit3",
		Markers = {
			[CombatMarkers.HitReactStart] = 0.000,
			[CombatMarkers.HitReactPeak] = 0.150,
			[CombatMarkers.RecoverEnd] = 0.833,
		},
	},
	Hit4 = {
		Id = "Hit4",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Reactions.Hit4",
		Markers = {
			[CombatMarkers.HitReactStart] = 0.000,
			[CombatMarkers.HitReactPeak] = 0.150,
			[CombatMarkers.RecoverEnd] = 0.800,
		},
	},
	Parried = {
		Id = "Parried",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Reactions.Parried",
		Markers = {
			[CombatMarkers.ParryStunStart] = 0.000,
			[CombatMarkers.ParryStunPeak] = 0.150,
			[CombatMarkers.RecoverEnd] = 1.350,
		},
	},
	BlockBreak = {
		Id = "BlockBreak",
		SequencePath = "ReplicatedStorage.Assets.CombatAnimations.Reactions.BlockBreak",
		Markers = {
			[CombatMarkers.BreakStart] = 0.000,
			[CombatMarkers.VulnerableStart] = 0.600,
			[CombatMarkers.RecoverEnd] = 3.333,
		},
	},
}

local markerCache = {}

local function resolvePath(path)
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end

	local firstSegment = table.remove(segments, 1)
	if not firstSegment then
		return nil
	end

	local current = game:FindFirstChild(firstSegment)
	if not current then
		local ok, service = pcall(function()
			return game:GetService(firstSegment)
		end)
		current = ok and service or nil
	end
	if not current then
		return nil
	end

	if #segments > 0 then
		local dottedName = table.concat(segments, ".")
		local directChild = current:FindFirstChild(dottedName)
		if directChild then
			return directChild
		end
	end

	for _, segment in ipairs(segments) do
		current = current:FindFirstChild(segment) or current:WaitForChild(segment, 5)
		if not current then
			return nil
		end
	end
	return current
end

local function extractMarkers(sequence)
	local markerTimes = {}
	for _, child in ipairs(sequence:GetChildren()) do
		if child:IsA("Keyframe") then
			for _, marker in ipairs(child:GetChildren()) do
				if marker:IsA("KeyframeMarker") then
					markerTimes[marker.Name] = child.Time
				end
			end
		end
	end
	return markerTimes
end

function CombatDefinitions.ResolveSequence(path)
	local sequence = resolvePath(path)
	assert(sequence and sequence:IsA("KeyframeSequence"), ("Missing KeyframeSequence: %s"):format(path))
	return sequence
end

function CombatDefinitions.GetMarkerTimes(path)
	local cached = markerCache[path]
	if cached then
		return cached
	end
	local definition = nil
	for _, source in pairs({ moveDefinitions, reactionDefinitions }) do
		for _, candidate in pairs(source) do
			if candidate.SequencePath == path and candidate.Markers then
				definition = candidate
				break
			end
		end
		if definition then
			break
		end
	end

	if definition and definition.Markers then
		cached = table.clone(definition.Markers)
	else
		local sequence = CombatDefinitions.ResolveSequence(path)
		cached = extractMarkers(sequence)
	end
	markerCache[path] = cached
	return cached
end

local function buildMoveRuntime(definition)
	local markers = CombatDefinitions.GetMarkerTimes(definition.SequencePath)
	local runtime = table.clone(definition)
	runtime.Markers = table.clone(markers)
	runtime.Startup = markers[CombatMarkers.ActiveStart] or 0
	runtime.ActiveDuration = math.max(0, (markers[CombatMarkers.ActiveEnd] or runtime.Startup) - runtime.Startup)
	runtime.RecoveryDuration = math.max(0, (markers[CombatMarkers.RecoverEnd] or (markers[CombatMarkers.ActiveEnd] or 0)) - (markers[CombatMarkers.ActiveEnd] or 0))
	runtime.TotalDuration = markers[CombatMarkers.RecoverEnd] or 0
	runtime.BufferOpen = markers[CombatMarkers.ComboBufferOpen]

	local contactTime = markers[CombatMarkers.Contact] or runtime.Startup
	local recoverEnd = markers[CombatMarkers.RecoverEnd] or runtime.TotalDuration or 0
	runtime.ContactTime = contactTime
	runtime.RecoveryAfterContact = math.max(0, recoverEnd - contactTime)
	runtime.BlockedRecoveryAfterContact = runtime.RecoveryAfterContact + (definition.BlockedRecoveryLock or 0)

	local hitstun = definition.Hitstun or 0
	if definition.ComboOnHitOnly == true then
		local nextMoveId = definition.NextMoves and definition.NextMoves[1]
		local nextDefinition = nextMoveId and moveDefinitions[nextMoveId]
		if nextDefinition then
			local nextMarkers = CombatDefinitions.GetMarkerTimes(nextDefinition.SequencePath)
			local nextContactTime = nextMarkers[CombatMarkers.Contact] or nextMarkers[CombatMarkers.ActiveStart] or 0
			local linkConfirmWindow = definition.LinkConfirmWindow or 0.03
			hitstun = math.max(hitstun, runtime.RecoveryAfterContact + nextContactTime + linkConfirmWindow)
			runtime.NextContactTime = nextContactTime
		end
	elseif type(definition.DesiredHitAdvantage) == "number" then
		hitstun = math.max(hitstun, runtime.RecoveryAfterContact + definition.DesiredHitAdvantage)
	end
	runtime.Hitstun = hitstun

	local blockstun = definition.Blockstun or 0
	if type(definition.DesiredBlockAdvantage) == "number" then
		blockstun = math.max(0, runtime.BlockedRecoveryAfterContact + definition.DesiredBlockAdvantage)
	end
	runtime.Blockstun = blockstun
	return runtime
end

function CombatDefinitions.GetMove(moveId)
	local definition = moveDefinitions[moveId]
	assert(definition, ("Unknown combat move: %s"):format(tostring(moveId)))
	return buildMoveRuntime(definition)
end

function CombatDefinitions.GetReaction(reactionId)
	local definition = reactionDefinitions[reactionId]
	assert(definition, ("Unknown combat reaction: %s"):format(tostring(reactionId)))
	local runtime = table.clone(definition)
	runtime.Markers = CombatDefinitions.GetMarkerTimes(definition.SequencePath)
	return runtime
end

function CombatDefinitions.GetLightCombo(index)
	local id = ({ "Light1", "Light2", "Light3", "Light4" })[math.clamp(index, 1, 4)]
	return CombatDefinitions.GetMove(id)
end

function CombatDefinitions.GetAllMoveIds()
	local ids = {}
	for id in pairs(moveDefinitions) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function CombatDefinitions.GetAllReactionIds()
	local ids = {}
	for id in pairs(reactionDefinitions) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return table.freeze(CombatDefinitions)
