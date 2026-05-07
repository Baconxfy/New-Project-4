local CombatAnimations = require(script.Parent.Parent.CombatAnimations)

local CombatPlayback = {}

function CombatPlayback.hydrateIdleAnimation(controller, sequencePath: string)
	local success, animationId = pcall(function()
		return CombatAnimations.GetAnimationIdFromPath(sequencePath)
	end)
	controller.IdleAnimationId = success and type(animationId) == "string" and animationId or nil
end

function CombatPlayback.stopWeaponIdle(controller, fadeTime: number?)
	local track = controller.IdleTrack
	controller.IdleTrack = nil
	if not track then
		return
	end
	pcall(function()
		track:Stop(fadeTime or 0.1)
		track:Destroy()
	end)
end

function CombatPlayback.playWeaponIdle(controller)
	if not controller.Animator or not controller.IdleAnimationId then
		return false
	end
	if controller.IdleTrack and controller.IdleTrack.IsPlaying then
		return true
	end
	local animation = CombatAnimations.CreateAnimation(controller.IdleAnimationId, "LightsaberIdle")
	local track = controller.Animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Idle
	track.Looped = true
	track:Play(0.15, 1, 1)
	track.Stopped:Once(function()
		animation:Destroy()
		if controller.IdleTrack == track then
			controller.IdleTrack = nil
		end
		track:Destroy()
	end)
	controller.IdleTrack = track
	return true
end

function CombatPlayback.refreshWeaponIdle(controller)
	if not controller.EquippedTool or controller.EquippedTool.Parent ~= controller.Character then
		CombatPlayback.stopWeaponIdle(controller, 0.1)
		return
	end
	if controller.CurrentMove or controller.Track then
		CombatPlayback.stopWeaponIdle(controller, 0.05)
		return
	end
	CombatPlayback.playWeaponIdle(controller)
end

function CombatPlayback.playReaction(controller, reactionId: string)
	if not controller.Animator then
		return false
	end
	local animationId = controller.ReactionCatalog[reactionId]
	if type(animationId) ~= "string" then
		return false
	end
	local animation = CombatAnimations.CreateAnimation(animationId, reactionId)
	local track = controller.Animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play(0.03, 1, 1)
	track.Stopped:Once(function()
		animation:Destroy()
		track:Destroy()
	end)
	return true
end

return table.freeze(CombatPlayback)
