local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local SetPowerUiClient = BaseComponent:Extend('SetPowerUiClient')

local DEFAULT_SET_POWER_SPEED = 1.4
local DEFAULT_POPUP_TIME = 0.65
local DEFAULT_PERFECT_THRESHOLD = 0.91
local DEFAULT_OKAY_THRESHOLD = 0.68

local function getMinigameConfig(framework)
	return (framework and framework.Config and framework.Config.Microwave and framework.Config.Microwave.Minigame) or {}
end

local function getPowerPercent(markerPercent: number): number
	return 1 - (math.abs(markerPercent - 0.5) * 2)
end

local function getResult(powerPercent: number, config): string
	if powerPercent >= (config.PerfectThreshold or DEFAULT_PERFECT_THRESHOLD) then
		return 'Perfect'
	elseif powerPercent >= (config.OkayThreshold or DEFAULT_OKAY_THRESHOLD) then
		return 'Okay'
	end
	return 'Bad'
end

local function getTextLabel(parent: Instance, name: string): TextLabel?
	local instance = parent:FindFirstChild(name, true)
	return if instance and instance:IsA('TextLabel') then instance else nil
end

local function getGuiObject(parent: Instance, name: string): GuiObject?
	local instance = parent:FindFirstChild(name, true)
	return if instance and instance:IsA('GuiObject') then instance else nil
end

function SetPowerUiClient:Create(gui: ScreenGui)
	self.Gui = gui
	self.Holder = getGuiObject(gui, 'Holder')
	self.TimingArea = getGuiObject(gui, 'TimingArea')
	self.StrikeLine = getGuiObject(gui, 'StrikeLine')
	self.PercentLabel = getTextLabel(gui, 'Percent')
	self.Popups = {
		Perfect = getTextLabel(gui, 'POPUPPERFECT'),
		Okay = getTextLabel(gui, 'POPUPOKAY'),
		Bad = getTextLabel(gui, 'POPUPBAD'),
	}

	assert(self.Holder, '[SetPowerUiClient] Missing Holder')
	assert(self.TimingArea, '[SetPowerUiClient] Missing TimingArea')
	if not self.StrikeLine then
		local strikeLine = Instance.new('Frame')
		strikeLine.Name = 'StrikeLine'
		strikeLine.AnchorPoint = Vector2.new(0.5, 0)
		strikeLine.Position = UDim2.fromScale(0, -0.3)
		strikeLine.Size = UDim2.fromScale(0.025, 1.6)
		strikeLine.BackgroundColor3 = Color3.new(1, 1, 1)
		strikeLine.BorderSizePixel = 0
		strikeLine.ZIndex = self.TimingArea.ZIndex + 4
		strikeLine.Parent = self.TimingArea
		self.StrikeLine = strikeLine
	end

	self.Bar = self.Framework.Components.TimedClickBarClient:new(self.StrikeLine, self.PercentLabel)
	self:AddChild(self.Bar)
	self:SetEnabled(false)
end

function SetPowerUiClient:SetEnabled(enabled: boolean)
	self.Gui.Enabled = enabled
end

function SetPowerUiClient:SetPopup(result: string?)
	for name, popup in pairs(self.Popups) do
		if popup then
			popup.Visible = name == result
		end
	end
end

function SetPowerUiClient:Play(onLocked: (number, string) -> (), speed: number?)
	self:SetEnabled(true)
	self:SetPopup(nil)
	local config = getMinigameConfig(self.Framework)

	self.Bar:Play({
		Speed = speed or config.SetPowerSpeed or DEFAULT_SET_POWER_SPEED,
		EdgeSpeedScale = config.ClickTimingEdgeSpeedScale,
		CenterSpeedScale = config.ClickTimingCenterSpeedScale,
		FormatPercent = getPowerPercent,
	}, function(markerPercent)
		local powerPercent = getPowerPercent(markerPercent)
		local result = getResult(powerPercent, config)
		self:SetPopup(result)
		onLocked(powerPercent, result)

		task.delay(config.PopupTime or DEFAULT_POPUP_TIME, function()
			if self._alive then
				self:SetEnabled(false)
			end
		end)
	end)
end

return SetPowerUiClient
