local CombatDefinitions = require(script.Parent.Parent.CombatDefinitions)

local CombatFrameData = {}

function CombatFrameData.AnalyzeMove(moveOrId)
	local move = type(moveOrId) == "string" and CombatDefinitions.GetMove(moveOrId) or moveOrId
	if type(move) ~= "table" then
		return nil
	end
	local recoveryAfterContact = move.RecoveryAfterContact or 0
	local blockedRecoveryAfterContact = move.BlockedRecoveryAfterContact or recoveryAfterContact
	local hitstun = move.Hitstun or 0
	local blockstun = move.Blockstun or 0
	local nextContactTime = move.NextContactTime
	local linkWindow = nil
	if type(nextContactTime) == "number" then
		linkWindow = hitstun - (recoveryAfterContact + nextContactTime)
	end
	return {
		MoveId = move.Id,
		Startup = move.Startup or 0,
		ActiveDuration = move.ActiveDuration or 0,
		RecoveryDuration = move.RecoveryDuration or 0,
		ContactTime = move.ContactTime or 0,
		RecoveryAfterContact = recoveryAfterContact,
		BlockedRecoveryAfterContact = blockedRecoveryAfterContact,
		Hitstun = hitstun,
		Blockstun = blockstun,
		HitAdvantage = hitstun - recoveryAfterContact,
		BlockAdvantage = blockstun - blockedRecoveryAfterContact,
		NextContactTime = nextContactTime,
		LinkWindow = linkWindow,
		ComboOnHitOnly = move.ComboOnHitOnly == true,
	}
end

function CombatFrameData.GetAllMoveAnalysis()
	local analysis = {}
	for _, moveId in ipairs(CombatDefinitions.GetAllMoveIds()) do
		analysis[moveId] = CombatFrameData.AnalyzeMove(moveId)
	end
	return analysis
end

return table.freeze(CombatFrameData)
