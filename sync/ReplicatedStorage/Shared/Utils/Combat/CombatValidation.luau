local CombatValidation = {}

function CombatValidation.validateContactEvidence(attackerCharacter: Model, attackerRoot: BasePart, targetCharacter: Model, targetRoot: BasePart, move, payload: any, hitValidationAngleDotMin: number, contactPositionTolerance: number, contactLineOfSightSlack: number, hitValidationRangeTolerance: number)
	local trace = move.Trace or {}
	local contactPoint = payload.ContactPoint
	if typeof(contactPoint) ~= "Vector3" then
		return false, "MissingContactPoint"
	end
	local attackerPosition = payload.AttackerPosition
	if attackerPosition and typeof(attackerPosition) == "Vector3" then
		if (attackerPosition - attackerRoot.Position).Magnitude > contactPositionTolerance then
			return false, "BadOriginSnapshot"
		end
	end
	local attackerLookVector = payload.AttackerLookVector
	if attackerLookVector and typeof(attackerLookVector) == "Vector3" and attackerLookVector.Magnitude > 0 then
		local directionToTarget = targetRoot.Position - attackerRoot.Position
		if directionToTarget.Magnitude > 0 and attackerLookVector.Unit:Dot(directionToTarget.Unit) < hitValidationAngleDotMin then
			return false, "BadClaimAngle"
		end
	end
	local maxDistance = (trace.Range or 8) + hitValidationRangeTolerance
	if (contactPoint - attackerRoot.Position).Magnitude > maxDistance then
		return false, "ContactTooFar"
	end
	if (contactPoint - targetRoot.Position).Magnitude > maxDistance then
		return false, "ContactMissedTarget"
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { attackerCharacter }
	raycastParams.IgnoreWater = true
	local direction = contactPoint - attackerRoot.Position
	if direction.Magnitude <= 0.001 then
		return false, "ZeroContactVector"
	end
	local raycastResult = workspace:Raycast(attackerRoot.Position, direction.Unit * (direction.Magnitude + contactLineOfSightSlack), raycastParams)
	if raycastResult and raycastResult.Instance and not raycastResult.Instance:IsDescendantOf(targetCharacter) then
		return false, "ObstructedContact"
	end
	return true
end

return table.freeze(CombatValidation)
