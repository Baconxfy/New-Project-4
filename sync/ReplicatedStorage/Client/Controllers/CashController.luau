local Players = game:GetService('Players')
local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local CashController = Framework:CreateController('CashController')

local CASH_STAT_NAME = 'Cash'
local MAIN_HUD_NAME = 'MainHUD'
local CASH_UI_NAME = 'CashUI'

local function formatMoney(value: number): string
	value = math.max(0, math.floor(value))
	if value >= 1000000 then
		return ('$%.1fM'):format(value / 1000000):gsub('%.0M', 'M')
	elseif value >= 1000 then
		return ('$%.1fK'):format(value / 1000):gsub('%.0K', 'K')
	end
	return ('$%d'):format(value)
end

function CashController:Initialize()
	self.Player = Players.LocalPlayer
	self.CashLabel = nil
	self.CashStat = nil
	self._cashConnection = nil
end

function CashController:Start()
	task.spawn(function()
		self:BindCashLabel()
		self:BindCashStat()
		self:RefreshCash()
	end)
end

function CashController:BindCashLabel()
	local playerGui = self.Player:WaitForChild('PlayerGui')
	local mainHud = playerGui:WaitForChild(MAIN_HUD_NAME, 20)
	if not mainHud then
		warn('[CashController] Missing MainHUD')
		return
	end

	local cashUi = mainHud:WaitForChild(CASH_UI_NAME, 20)
	if not cashUi then
		warn('[CashController] Missing MainHUD.CashUI')
		return
	end

	local label = cashUi:WaitForChild('TextLabel', 20)
	if not label or not label:IsA('TextLabel') then
		warn('[CashController] Missing MainHUD.CashUI.TextLabel')
		return
	end

	self.CashLabel = label
end

function CashController:BindCashStat()
	local leaderstats = self.Player:WaitForChild('leaderstats', 20)
	if not leaderstats then
		warn('[CashController] Missing leaderstats')
		return
	end

	local cash = leaderstats:WaitForChild(CASH_STAT_NAME, 20)
	if not cash or not cash:IsA('IntValue') then
		warn('[CashController] Missing leaderstats.Cash')
		return
	end

	self.CashStat = cash
	if self._cashConnection then
		self._cashConnection:Disconnect()
	end

	self._cashConnection = cash:GetPropertyChangedSignal('Value'):Connect(function()
		self:RefreshCash()
	end)
	self:AddConnection(self._cashConnection)
end

function CashController:RefreshCash()
	if not self.CashLabel or not self.CashStat then
		return
	end

	self.CashLabel.Text = formatMoney(self.CashStat.Value)
end

return CashController
