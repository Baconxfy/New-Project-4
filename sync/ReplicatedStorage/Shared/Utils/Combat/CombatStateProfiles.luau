local CombatStateProfiles = {}

local PROFILES = {
	Hit = {
		WalkSpeedMultiplier = 0.15,
		JumpEnabled = false,
	},
	Blocked = {
		WalkSpeedMultiplier = 0.35,
		JumpEnabled = false,
	},
	Recovery = {
		WalkSpeedMultiplier = 0.45,
		JumpEnabled = false,
	},
	Staggered = {
		WalkSpeedMultiplier = 0,
		JumpEnabled = false,
	},
	BlockBroken = {
		WalkSpeedMultiplier = 0,
		JumpEnabled = false,
	},
	Parried = {
		WalkSpeedMultiplier = 0,
		JumpEnabled = false,
	},
}

function CombatStateProfiles.Get(outcome: string)
	local profile = PROFILES[outcome]
	if not profile then
		return nil
	end
	return table.clone(profile)
end

return table.freeze(CombatStateProfiles)
