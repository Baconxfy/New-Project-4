local CombatResolution = {}

function CombatResolution.applyOutcome(service, result)
	local move = result.Move
	local outcome = result.Outcome or "Hit"
	if outcome == "Hit" then
		local damage = move.Damage or 10
		result.TargetHumanoid:TakeDamage(damage)
		service:_playReaction(result.TargetCharacter, move.ReactionId)
		return {
			Outcome = outcome,
			Damage = damage,
			ChipDamage = 0,
			GuardDamage = 0,
			GuardRemaining = nil,
			ReactionId = move.ReactionId,
		}
	elseif outcome == "Blocked" then
		local chipDamage = result.ChipDamage or 0
		if chipDamage > 0 then
			result.TargetHumanoid:TakeDamage(chipDamage)
		end
		return {
			Outcome = outcome,
			Damage = chipDamage,
			ChipDamage = chipDamage,
			GuardDamage = result.GuardDamage or 0,
			GuardRemaining = result.GuardRemaining,
			ReactionId = result.ReactionId,
		}
	elseif outcome == "BlockBroken" then
		local chipDamage = result.ChipDamage or 0
		if chipDamage > 0 then
			result.TargetHumanoid:TakeDamage(chipDamage)
		end
		local reactionId = result.ReactionId or "BlockBreak"
		service:_playReaction(result.TargetCharacter, reactionId)
		return {
			Outcome = outcome,
			Damage = chipDamage,
			ChipDamage = chipDamage,
			GuardDamage = result.GuardDamage or 0,
			GuardRemaining = result.GuardRemaining,
			ReactionId = reactionId,
		}
	elseif outcome == "Staggered" then
		local damage = move.Damage or 10
		result.TargetHumanoid:TakeDamage(damage)
		local reactionId = result.ReactionId or move.ReactionId or "Hit4"
		service:_playReaction(result.TargetCharacter, reactionId)
		return {
			Outcome = outcome,
			Damage = damage,
			ChipDamage = 0,
			GuardDamage = 0,
			GuardRemaining = result.GuardRemaining,
			ReactionId = reactionId,
			PostureDamage = result.PostureDamage or 0,
			PostureRemaining = result.PostureRemaining,
		}
	elseif outcome == "Parried" then
		return {
			Outcome = outcome,
			Damage = 0,
			ChipDamage = 0,
			GuardDamage = 0,
			GuardRemaining = result.GuardRemaining,
			ReactionId = "Parried",
		}
	end
	return {
		Outcome = outcome,
		Damage = 0,
		ChipDamage = result.ChipDamage or 0,
		GuardDamage = result.GuardDamage or 0,
		GuardRemaining = result.GuardRemaining,
		ReactionId = result.ReactionId,
		PostureDamage = result.PostureDamage or 0,
		PostureRemaining = result.PostureRemaining,
	}
end

return table.freeze(CombatResolution)
