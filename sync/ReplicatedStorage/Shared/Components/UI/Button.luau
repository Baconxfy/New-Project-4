local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local Button = BaseComponent:Extend('Button')

local DEFAULT_TRACK_PROPS = {
	'BackgroundColor3',
	'BackgroundTransparency',
	'BorderColor3',
	'BorderSizePixel',
	'Size',
	'Position',
	'AnchorPoint',
	'Rotation',
	'Visible',
	'ZIndex',
	'Text',
	'TextColor3',
	'TextTransparency',
	'TextStrokeColor3',
	'TextStrokeTransparency',
	'TextSize',
	'Font',
	'FontFace',
	'RichText',
	'Image',
	'ImageColor3',
	'ImageTransparency',
	'ImageRectOffset',
	'ImageRectSize',
	'LayoutOrder',
	'AutoButtonColor',
}

local DEFAULT_ANIM = {
	Enabled = true,
	HoverEnabled = true,
	PressEnabled = true,
	HoverScale = 1.06,
	PressScale = 0.94,
	HoverTime = 0.12,
	PressDownTime = 0.07,
	PressUpTime = 0.10,
	ClickSlopPx = 6,
	HoverEasingStyle = Enum.EasingStyle.Quint,
	HoverEasingDirection = Enum.EasingDirection.Out,
	PressDownEasingStyle = Enum.EasingStyle.Quint,
	PressDownEasingDirection = Enum.EasingDirection.Out,
	PressUpEasingStyle = Enum.EasingStyle.Back,
	PressUpEasingDirection = Enum.EasingDirection.Out,
}

local function copyConfig(base, override)
	local config = table.clone(base)
	for key, value in pairs(override or {}) do
		config[key] = value
	end
	return config
end

local function snapshotProps(gui: Instance, props)
	local snapshot = {}
	for _, prop in ipairs(props) do
		local ok, value = pcall(function()
			return (gui :: any)[prop]
		end)
		if ok then
			snapshot[prop] = value
		end
	end
	return snapshot
end

local function diffProps(before, after)
	local changedOriginals = {}
	for prop, beforeValue in pairs(before) do
		if after[prop] ~= beforeValue then
			changedOriginals[prop] = beforeValue
		end
	end
	return changedOriginals
end

local function applyProps(gui: Instance, values)
	for prop, value in pairs(values) do
		pcall(function()
			(gui :: any)[prop] = value
		end)
	end
end

local function ensureUIScale(gui: GuiObject): UIScale
	local scale = gui:FindFirstChildOfClass('UIScale')
	if scale then
		return scale
	end

	scale = Instance.new('UIScale')
	scale.Scale = 1
	scale.Parent = gui
	return scale
end

local function makeTweenInfo(time: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): TweenInfo
	return TweenInfo.new(time, style, direction)
end

local function pointInRect(px: number, py: number, x: number, y: number, width: number, height: number): boolean
	return px >= x and px <= x + width and py >= y and py <= y + height
end

function Button:Create(guiObject: GuiObject, propsToTrack, options)
	assert(guiObject and guiObject:IsA('GuiObject'), '[Button] Create expects a GuiObject')
	assert(guiObject:IsA('GuiButton'), '[Button] requires a GuiButton')

	self.Gui = guiObject :: GuiButton
	self.Gui.AutoButtonColor = false
	self.Name = self.Gui.Name
	self.DestroyGuiOnCleanUp = type(options) == 'table' and options.DestroyGuiOnCleanUp == true
	self._props = if type(propsToTrack) == 'table' then propsToTrack else DEFAULT_TRACK_PROPS
	self.Anim = copyConfig(DEFAULT_ANIM, self.Framework.Config and self.Framework.Config.Button)
	self.Anim.ClickSlopPx = tonumber(self.Anim.ClickSlopPx) or DEFAULT_ANIM.ClickSlopPx

	self._onClick = nil
	self._onHoverEnter = nil
	self._onHoverLeave = nil
	self._onPressDown = nil
	self._onPressUp = nil
	self._scaleTween = nil
	self._revertMap = {}
	self._pressBegan = false
	self._activatedFired = false
	self._lastPressInput = nil
	self.Hovering = false
	self.Pressed = false

	self._scale = ensureUIScale(self.Gui)
	self._baseScale = self._scale.Scale

	self:AddConnection(self.Gui.Destroying:Connect(function()
		self:Destroy()
	end))

	self:AddConnection(self.Gui.MouseEnter:Connect(function()
		if not self._alive then
			return
		end
		self.Hovering = true

		local before = snapshotProps(self.Gui, self._props)
		self:ApplyHoverScale()

		if self._onHoverEnter then
			self._onHoverEnter(self)
		end

		local after = snapshotProps(self.Gui, self._props)
		self._revertMap = diffProps(before, after)
	end))

	self:AddConnection(self.Gui.MouseLeave:Connect(function()
		if not self._alive then
			return
		end
		self.Hovering = false

		if not self.Pressed then
			self:TweenScale(self:GetNormalScale(), makeTweenInfo(self.Anim.HoverTime, self.Anim.HoverEasingStyle, self.Anim.HoverEasingDirection))
		end

		if self._onHoverLeave then
			self._onHoverLeave(self)
		else
			applyProps(self.Gui, self._revertMap)
		end
		self._revertMap = {}
	end))

	self:AddConnection(self.Gui.Activated:Connect(function(input: InputObject?)
		if not self._alive then
			return
		end
		self._activatedFired = true
		if self._onClick then
			self._onClick(self, input)
		end
	end))

	self:AddConnection(self.Gui.InputBegan:Connect(function(input: InputObject)
		if not self._alive then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.Pressed = true
			self._pressBegan = true
			self._activatedFired = false
			self._lastPressInput = input
			self:ApplyPressScaleDown()
			if self._onPressDown then
				self._onPressDown(self, input)
			end
		end
	end))

	self:AddConnection(self.Gui.InputEnded:Connect(function(input: InputObject)
		if not self._alive then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		self.Pressed = false
		self:ApplyScaleRelease()
		if self._onPressUp then
			self._onPressUp(self, input)
		end

		if self._pressBegan and not self._activatedFired and self._onClick then
			local position = input.Position
			if typeof(position) == 'Vector3' then
				local absolutePosition = self.Gui.AbsolutePosition
				local absoluteSize = self.Gui.AbsoluteSize
				local slop = self.Anim.ClickSlopPx
				local inside = pointInRect(
					position.X,
					position.Y,
					absolutePosition.X - slop,
					absolutePosition.Y - slop,
					absoluteSize.X + slop * 2,
					absoluteSize.Y + slop * 2
				)

				if inside then
					self._onClick(self, input)
				end
			end
		end

		self._pressBegan = false
		self._lastPressInput = nil
	end))

	self:AddConnection(self.Gui.SelectionGained:Connect(function()
		if not self._alive then
			return
		end
		self.Hovering = true
		self:ApplyHoverScale()
		if self._onHoverEnter then
			self._onHoverEnter(self)
		end
	end))

	self:AddConnection(self.Gui.SelectionLost:Connect(function()
		if not self._alive then
			return
		end
		self.Hovering = false
		if not self.Pressed then
			self:TweenScale(self:GetNormalScale(), makeTweenInfo(self.Anim.HoverTime, self.Anim.HoverEasingStyle, self.Anim.HoverEasingDirection))
		end
		if self._onHoverLeave then
			self._onHoverLeave(self)
		end
	end))
end

function Button:CancelScaleTween()
	if self._scaleTween then
		self._scaleTween:Cancel()
		self._scaleTween = nil
	end
end

function Button:TweenScale(target: number, tweenInfo: TweenInfo)
	if not self.Anim.Enabled then
		return
	end

	self:CancelScaleTween()
	self._scaleTween = TweenService:Create(self._scale, tweenInfo, { Scale = target })
	self._scaleTween:Play()
end

function Button:GetNormalScale(): number
	return self._baseScale
end

function Button:GetHoverScale(): number
	return self._baseScale * self.Anim.HoverScale
end

function Button:GetPressScale(): number
	return self._baseScale * self.Anim.PressScale
end

function Button:ApplyHoverScale()
	if not self.Anim.Enabled or not self.Anim.HoverEnabled or self.Pressed then
		return
	end

	self:TweenScale(self:GetHoverScale(), makeTweenInfo(self.Anim.HoverTime, self.Anim.HoverEasingStyle, self.Anim.HoverEasingDirection))
end

function Button:ApplyPressScaleDown()
	if not self.Anim.Enabled or not self.Anim.PressEnabled then
		return
	end

	self:TweenScale(self:GetPressScale(), makeTweenInfo(self.Anim.PressDownTime, self.Anim.PressDownEasingStyle, self.Anim.PressDownEasingDirection))
end

function Button:ApplyScaleRelease()
	local target = if self.Hovering and self.Anim.HoverEnabled then self:GetHoverScale() else self:GetNormalScale()
	self:TweenScale(target, makeTweenInfo(self.Anim.PressUpTime, self.Anim.PressUpEasingStyle, self.Anim.PressUpEasingDirection))
end

function Button:SetOnClick(callback)
	self._onClick = callback
	return self
end

function Button:SetOnHoverEnter(callback)
	self._onHoverEnter = callback
	return self
end

function Button:SetOnHoverLeave(callback)
	self._onHoverLeave = callback
	return self
end

function Button:SetOnPressDown(callback)
	self._onPressDown = callback
	return self
end

function Button:SetOnPressUp(callback)
	self._onPressUp = callback
	return self
end

function Button:CleanUp()
	self:CancelScaleTween()
	if self._scale and self._scale.Parent then
		self._scale.Scale = self._baseScale or 1
	end
	if self.DestroyGuiOnCleanUp and self.Gui and self.Gui.Parent then
		self.Gui:Destroy()
	end
end

return Button
