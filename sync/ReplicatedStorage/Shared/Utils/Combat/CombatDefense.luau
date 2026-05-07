local CombatDefense = {}

function CombatDefense.isParryActive(state, now: number)
	return now >= state.ParryWindowStartAt and now <= state.ParryWindowEndAt
end

function CombatDefense.isBlockActive(state, now: number)
	return state.IsBlocking == true and now >= (state.BlockWindowStartAt or 0) and now >= (state.GuardBrokenUntil or 0)
end

function CombatDefense.getCharacterCombatState(service, character: Model)
	local player = game:GetService("Players"):GetPlayerFromCharacter(character)
	if player then
		return service:_ensurePlayerState(player), true
	end
	return nil, false
end

function CombatDefense.getCharacterGuardMeter(character: Model, state, defaultGuardMeterMax: number)
	if state then
		return state.GuardMeter or defaultGuardMeterMax
	end
	return character:GetAttribute("CombatGuardMeter") or defaultGuardMeterMax
end

function CombatDefense.setCharacterGuardMeter(character: Model, state, value: number)
	local clamped = math.max(0, value)
	if state then
		state.GuardMeter = clamped
	else
		character:SetAttribute("CombatGuardMeter", clamped)
	end
	return clamped
end

function CombatDefense.setCharacterBlockActive(character: Model, state, isActive: boolean, activeStartAt: number?)
	if state then
		state.IsBlocking = isActive
		state.BlockWindowStartAt = isActive and (activeStartAt or 0) or 0
	else
		character:SetAttribute("CombatDefenseMode", isActive and "Block" or "None")
		character:SetAttribute("CombatDefenseStartAt", isActive and (activeStartAt or 0) or 0)
	end
end

function CombatDefense.setCharacterParryWindow(character: Model, state, startAt: number, endAt: number)
	if state then
		state.ParryWindowStartAt = startAt
		state.ParryWindowEndAt = endAt
	else
		character:SetAttribute("CombatDefenseMode", "Parry")
		character:SetAttribute("CombatDefenseStartAt", startAt)
		character:SetAttribute("CombatDefenseEndsAt", endAt)
	end
end

function CombatDefense.clearCharacterParryWindow(character: Model, state)
	if state then
		state.ParryWindowStartAt = 0
		state.ParryWindowEndAt = 0
	else
		if character:GetAttribute("CombatDefenseMode") == "Parry" then
			character:SetAttribute("CombatDefenseMode", "None")
		end
		character:SetAttribute("CombatDefenseStartAt", 0)
		character:SetAttribute("CombatDefenseEndsAt", 0)
	end
end

function CombatDefense.isCharacterParryActive(character: Model, state, now: number)
	if state then
		return CombatDefense.isParryActive(state, now)
	end
	return character:GetAttribute("CombatDefenseMode") == "Parry"
		and now >= (character:GetAttribute("CombatDefenseStartAt") or 0)
		and now <= (character:GetAttribute("CombatDefenseEndsAt") or 0)
end

function CombatDefense.isCharacterBlockActive(character: Model, state, now: number)
	if state then
		return CombatDefense.isBlockActive(state, now)
	end
	return character:GetAttribute("CombatDefenseMode") == "Block"
		and now >= (character:GetAttribute("CombatDefenseStartAt") or 0)
		and now >= (character:GetAttribute("CombatGuardBrokenUntil") or 0)
end

function CombatDefense.applyGuardBreak(character: Model, state, now: number, breakDuration: number, setCharacterBlockActive, setCharacterGuardMeter)
	setCharacterBlockActive(character, state, false)
	setCharacterGuardMeter(character, state, 0)
	if state then
		state.GuardBrokenUntil = now + breakDuration
		state.StaggeredUntil = math.max(state.StaggeredUntil or 0, now + breakDuration)
		state.LastGuardHitAt = now
	else
		character:SetAttribute("CombatGuardBrokenUntil", now + breakDuration)
		character:SetAttribute("CombatStaggeredUntil", now + breakDuration)
		character:SetAttribute("CombatLastGuardHitAt", now)
		character:SetAttribute("CombatDefenseMode", "None")
	end
end

return table.freeze(CombatDefense)
