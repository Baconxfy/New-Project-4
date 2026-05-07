local TweenService = game:GetService("TweenService")

local CombatFeedbackProfiles = require(script.Parent.CombatFeedbackProfiles)

local CombatFeedback = {}

local function emit(controller, payload)
	if controller.FeedbackTriggered then
		controller.FeedbackTriggered:Fire(payload)
	end
end

local function applyTrackHitstop(controller, duration: number)
	if duration <= 0 then
		return
	end
	local track = controller.Track
	if not track then
		return
	end
	controller._feedbackHitstopToken = (controller._feedbackHitstopToken or 0) + 1
	local token = controller._feedbackHitstopToken
	local previousSpeed = track.Speed
	pcall(function()
		track:AdjustSpeed(0)
	end)
	task.delay(duration, function()
		if controller._feedbackHitstopToken ~= token then
			return
		end
		if controller.Track ~= track then
			return
		end
		pcall(function()
			track:AdjustSpeed(previousSpeed > 0 and previousSpeed or 1)
		end)
	end)
end

local function applyCameraKick(controller, profile)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local currentToken = (controller._cameraFeedbackToken or 0) + 1
	controller._cameraFeedbackToken = currentToken
	if controller._cameraFeedbackUpTween then
		controller._cameraFeedbackUpTween:Cancel()
		controller._cameraFeedbackUpTween = nil
	end
	if controller._cameraFeedbackDownTween then
		controller._cameraFeedbackDownTween:Cancel()
		controller._cameraFeedbackDownTween = nil
	end
	local baseFov = camera.FieldOfView
	local peakFov = baseFov + (profile.FovKick or 0)
	local riseTween = TweenService:Create(camera, TweenInfo.new(profile.RiseTime or 0.03, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = peakFov,
	})
	local fallTween = TweenService:Create(camera, TweenInfo.new(profile.FallTime or 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = baseFov,
	})
	controller._cameraFeedbackUpTween = riseTween
	controller._cameraFeedbackDownTween = fallTween
	riseTween.Completed:Once(function()
		if controller._cameraFeedbackToken ~= currentToken then
			return
		end
		fallTween:Play()
	end)
	fallTween.Completed:Once(function()
		if controller._cameraFeedbackToken ~= currentToken then
			return
		end
		camera.FieldOfView = baseFov
		controller._cameraFeedbackUpTween = nil
		controller._cameraFeedbackDownTween = nil
	end)
	riseTween:Play()
end

local function applyProfile(controller, payload, profile)
	applyTrackHitstop(controller, profile.Hitstop or 0)
	applyCameraKick(controller, profile)
	emit(controller, payload)
end

function CombatFeedback.applySoftConfirm(controller, move, targetCharacter: Model)
	local profile = CombatFeedbackProfiles.GetSoftConfirm(move)
	applyProfile(controller, {
		Type = "SoftConfirm",
		Move = move and move.Id or nil,
		Target = targetCharacter,
		Profile = profile,
		At = os.clock(),
	}, profile)
	return profile
end

function CombatFeedback.applyHardConfirm(controller, move, targetCharacter: Model, result)
	local outcome = type(result) == "table" and result.Outcome or "Hit"
	local profile = CombatFeedbackProfiles.GetOutcome(outcome)
	applyProfile(controller, {
		Type = outcome,
		Move = move and move.Id or nil,
		Target = targetCharacter,
		Result = result,
		Profile = profile,
		At = os.clock(),
	}, profile)
	return profile
end

function CombatFeedback.applyRejectedAction(controller, actionName: string, move, result)
	local profile = CombatFeedbackProfiles.GetOutcome("Rejected")
	applyProfile(controller, {
		Type = "Rejected",
		ActionName = actionName,
		Move = move and move.Id or nil,
		Result = result,
		Profile = profile,
		At = os.clock(),
	}, profile)
	return profile
end

return table.freeze(CombatFeedback)
