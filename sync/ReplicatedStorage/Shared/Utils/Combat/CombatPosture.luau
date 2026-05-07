local CombatPosture = {}

function CombatPosture.getCharacterPosture(character: Model, state, defaultPostureMax: number)
	if state then
		return state.Posture or defaultPostureMax
	end
	return character:GetAttribute("CombatPosture") or defaultPostureMax
end

function CombatPosture.setCharacterPosture(character: Model, state, value: number)
	local clamped = math.max(0, value)
	if state then
		state.Posture = clamped
	else
		character:SetAttribute("CombatPosture", clamped)
	end
	return clamped
end

function CombatPosture.applyPostureDamage(character: Model, state, amount: number, maxPosture: number)
	local current = CombatPosture.getCharacterPosture(character, state, maxPosture)
	return CombatPosture.setCharacterPosture(character, state, current - amount)
end

function CombatPosture.markPostureHit(character: Model, state, now: number)
	if state then
		state.LastPostureHitAt = now
	else
		character:SetAttribute("CombatLastPostureHitAt", now)
	end
end

function CombatPosture.getLastPostureHitAt(character: Model, state)
	if state then
		return state.LastPostureHitAt or 0
	end
	return character:GetAttribute("CombatLastPostureHitAt") or 0
end

function CombatPosture.applyStagger(character: Model, state, now: number, duration: number, resetValue: number)
	if state then
		state.StaggeredUntil = now + duration
		state.LastPostureHitAt = now
		state.Posture = resetValue
	else
		character:SetAttribute("CombatStaggeredUntil", now + duration)
		character:SetAttribute("CombatLastPostureHitAt", now)
		character:SetAttribute("CombatPosture", resetValue)
	end
end

function CombatPosture.isCharacterStaggered(character: Model, state, now: number)
	if state then
		return now < (state.StaggeredUntil or 0)
	end
	return now < (character:GetAttribute("CombatStaggeredUntil") or 0)
end

return table.freeze(CombatPosture)
