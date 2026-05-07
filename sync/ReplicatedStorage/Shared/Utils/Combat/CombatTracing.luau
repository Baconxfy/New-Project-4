local CombatTracing = {}

function CombatTracing.getBladePart(controller)
	local tool = controller.EquippedTool
	if not tool or tool.Parent ~= controller.Character then
		return nil
	end
	local blade = tool:FindFirstChild("_OuterBlade") or tool:FindFirstChild("_InnerBlade")
	if blade and blade:IsA("BasePart") then
		return blade
	end
	return nil
end

function CombatTracing.getTraceBox(controller, move)
	local trace = move.Trace
	if type(trace) ~= "table" or not controller.Character then
		return nil, nil
	end
	local rootPart = controller.Character:FindFirstChild("HumanoidRootPart") or controller.Character.PrimaryPart
	if not rootPart then
		return nil, nil
	end
	local range = trace.Range or 8
	local depth = trace.Depth or (range + 1.5)
	local forwardOffset = trace.ForwardOffset or (range * 0.65)
	local verticalOffset = trace.VerticalOffset or 0
	local boxCFrame = rootPart.CFrame * CFrame.new(0, verticalOffset, -(forwardOffset))
	local boxSize = Vector3.new(trace.Width or 5, trace.Height or 4, depth)
	return boxCFrame, boxSize
end

function CombatTracing.proveBladeContact(controller, move, targetCharacter: Model)
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart") or targetCharacter.PrimaryPart
	local attackerRoot = controller.Character and (controller.Character:FindFirstChild("HumanoidRootPart") or controller.Character.PrimaryPart)
	if not targetRoot or not attackerRoot then
		return nil
	end
	local delta = targetRoot.Position - attackerRoot.Position
	local normal = delta.Magnitude > 0 and delta.Unit or attackerRoot.CFrame.LookVector
	return {
		HitPosition = targetRoot.Position,
		HitNormal = normal,
		SampleOffset = 0,
	}
end

function CombatTracing.buildHitClaim(controller, move, targetCharacter: Model, contactProof)
	local rootPart = controller.Character and (controller.Character:FindFirstChild("HumanoidRootPart") or controller.Character.PrimaryPart)
	return {
		AttackId = controller.CurrentAttackId,
		MoveId = move.Id,
		TargetCharacter = targetCharacter,
		ClientTime = os.clock(),
		ContactPoint = contactProof and contactProof.HitPosition or nil,
		ContactNormal = contactProof and contactProof.HitNormal or nil,
		SampleOffset = contactProof and contactProof.SampleOffset or nil,
		AttackerPosition = rootPart and rootPart.Position or nil,
		AttackerLookVector = rootPart and rootPart.CFrame.LookVector or nil,
	}
end

return table.freeze(CombatTracing)
