local CombatFeedbackProfiles = {}

local OUTCOME_PROFILES = {
	SoftConfirm = {
		Hitstop = 0.03,
		FovKick = 1.25,
		RiseTime = 0.025,
		FallTime = 0.08,
	},
	Hit = {
		Hitstop = 0.045,
		FovKick = 2.25,
		RiseTime = 0.03,
		FallTime = 0.10,
	},
	Blocked = {
		Hitstop = 0.03,
		FovKick = 1.4,
		RiseTime = 0.025,
		FallTime = 0.09,
	},
	BlockBroken = {
		Hitstop = 0.06,
		FovKick = 3.0,
		RiseTime = 0.035,
		FallTime = 0.12,
	},
	Staggered = {
		Hitstop = 0.065,
		FovKick = 3.2,
		RiseTime = 0.035,
		FallTime = 0.13,
	},
	Parried = {
		Hitstop = 0.075,
		FovKick = 3.4,
		RiseTime = 0.04,
		FallTime = 0.14,
	},
	Rejected = {
		Hitstop = 0,
		FovKick = 0.8,
		RiseTime = 0.02,
		FallTime = 0.05,
	},
}

local function cloneProfile(profile)
	return table.clone(profile)
end

function CombatFeedbackProfiles.GetSoftConfirm(move)
	local profile = cloneProfile(OUTCOME_PROFILES.SoftConfirm)
	if type(move) == "table" and type(move.SoftConfirmHitstop) == "number" then
		profile.Hitstop = move.SoftConfirmHitstop
	end
	return profile
end

function CombatFeedbackProfiles.GetOutcome(outcome: string)
	return cloneProfile(OUTCOME_PROFILES[outcome] or OUTCOME_PROFILES.Hit)
end

return table.freeze(CombatFeedbackProfiles)
