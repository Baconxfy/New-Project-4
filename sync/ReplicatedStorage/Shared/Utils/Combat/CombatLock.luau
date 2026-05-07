local CombatLock = {}

function CombatLock.getCharacterActionLockedUntil(character: Model, state)
	if state then
		return state.ActionLockedUntil or 0
	end
	return character:GetAttribute("CombatActionLockedUntil") or 0
end

function CombatLock.isCharacterActionLocked(character: Model, state, now: number)
	return now < CombatLock.getCharacterActionLockedUntil(character, state)
end

function CombatLock.lockCharacterActions(character: Model, state, now: number, duration: number)
	duration = duration or 0
	if duration <= 0 then
		return CombatLock.getCharacterActionLockedUntil(character, state)
	end
	local lockedUntil = math.max(CombatLock.getCharacterActionLockedUntil(character, state), now + duration)
	if state then
		state.ActionLockedUntil = lockedUntil
	else
		character:SetAttribute("CombatActionLockedUntil", lockedUntil)
	end
	return lockedUntil
end

return table.freeze(CombatLock)
