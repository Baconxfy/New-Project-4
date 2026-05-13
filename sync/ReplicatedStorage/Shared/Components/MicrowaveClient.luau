local Lighting = game:GetService('Lighting')
local ContentProvider = game:GetService('ContentProvider')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)
local BrainrotBillboard = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('BrainrotBillboard'))

local MicrowaveClient = BaseComponent:Extend('MicrowaveClient')

local DEFAULT_COOK_TIME = 5
local DEFAULT_REVEAL_TIME = 1.85
local DEFAULT_ROLL_TIME = 2.35
local DEFAULT_CAMERA_TWEEN_TIME = 0.55
local DEFAULT_UI_HANDOFF_DELAY = 0.15
local DEFAULT_START_CAMERA_OFFSET = Vector3.new(0, 1.6, 4.5)
local DEFAULT_COOK_CAMERA_OFFSET = Vector3.new(0, 1.25, 3.35)
local DEFAULT_REVEAL_CAMERA_OFFSET = Vector3.new(0, 1.08, 2.85)
local DEFAULT_FOCUS_OFFSET = Vector3.new(0, 0.75, 0)
local DEFAULT_COOK_COLOR = Color3.fromRGB(255, 158, 60)
local DEFAULT_HOT_COLOR = Color3.fromRGB(255, 65, 25)
local DEFAULT_REVEAL_COLOR = Color3.fromRGB(255, 245, 150)
local DEFAULT_RARITY_COLORS = {
	Common = Color3.fromRGB(235, 235, 235),
	Rare = Color3.fromRGB(75, 155, 255),
	Epic = Color3.fromRGB(185, 95, 255),
	Legendary = Color3.fromRGB(255, 185, 65),
	Mythic = Color3.fromRGB(255, 70, 95),
	Godly = Color3.fromRGB(255, 245, 95),
	Secret = Color3.fromRGB(80, 255, 230),
	Divine = Color3.fromRGB(255, 255, 255),
	Celestine = Color3.fromRGB(105, 170, 255),
	Forbidden = Color3.fromRGB(255, 45, 45),
}
local DEFAULT_TRAY_NAMES = {
	'MicrowaveTray',
	'Turntable',
	'Tray',
	'Plate',
}
local ROLL_RARITY_NAMES = {
	Common = true,
	Rare = true,
	Epic = true,
	Legendary = true,
	Mythic = true,
	Godly = true,
	Secret = true,
	Divine = true,
	Celestine = true,
	Forbidden = true,
}

local BRAINROT_MODELS = ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Brainrots')
local NORMAL_BRAINROT_MODELS = BRAINROT_MODELS:WaitForChild('Normal')
local ROLLING_ANIM_BRAINROT_MODELS = BRAINROT_MODELS:WaitForChild('RollingAnim')
local PRELOADED_TEMPLATES = setmetatable({}, { __mode = 'k' })
local ROLL_TEMPLATE_CACHE = {}
local ROLLING_HIGHLIGHT_NAME = 'Rolling Anim Highlight'
local ROLLING_HIGHLIGHT_TEMPLATE: Highlight? = nil

local function getModelFromFolder(parent: Instance?, folderName: string): Model?
	local folder = parent and parent:FindFirstChild(folderName)
	return folder and folder:FindFirstChildWhichIsA('Model') or nil
end

local function getRootPart(model: Model): BasePart?
	local centerCube = model:FindFirstChild('CenterCube', true)
	if centerCube and centerCube:IsA('BasePart') then
		return centerCube
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart', true)
end

local function getMicrowaveConfig(framework)
	return (framework and framework.Config and framework.Config.Microwave) or {}
end

local function getMicrowaveMinigameConfig(framework)
	return getMicrowaveConfig(framework).Minigame or {}
end

local function getMicrowaveClientConfig(framework)
	return getMicrowaveConfig(framework).Client or {}
end

local function getPivot(instance: Instance): CFrame?
	if instance:IsA('Model') then
		return instance:GetPivot()
	elseif instance:IsA('BasePart') then
		return instance.CFrame
	end

	return nil
end

local function pivotTo(instance: Instance, cframe: CFrame)
	if instance:IsA('Model') then
		instance:PivotTo(cframe)
	elseif instance:IsA('BasePart') then
		instance.CFrame = cframe
	end
end

local function prepPreviewModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BasePart') then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function setLocalTransparency(model: Model, transparency: number)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BasePart') then
			descendant.LocalTransparencyModifier = transparency
		end
	end
end

local function setVisualEffectsEnabled(model: Model, enabled: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('ParticleEmitter') or descendant:IsA('Beam') or descendant:IsA('Trail') then
			descendant.Enabled = enabled
		elseif descendant:IsA('Light') then
			descendant.Enabled = enabled
		end
	end
end

local function normalizeName(value: any): string
	return tostring(value or ''):lower():gsub('%W', '')
end

local function findModelByLooseName(root: Instance, modelName: string): Model?
	local wanted = normalizeName(modelName)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA('Model') and normalizeName(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

local function findDirectChildByLooseName(root: Instance, childName: string): Instance?
	local wanted = normalizeName(childName)
	for _, child in ipairs(root:GetChildren()) do
		if normalizeName(child.Name) == wanted then
			return child
		end
	end
	return nil
end

local function findBrainrotTemplateInRoot(root: Instance, name: string, rarity: string?): Model?
	local modelName = tostring(name)
	if type(rarity) == 'string' then
		local rarityFolder = root:FindFirstChild(rarity)
		local template = rarityFolder and rarityFolder:FindFirstChild(modelName)
		if template and template:IsA('Model') then
			return template
		end
		if rarityFolder then
			template = findModelByLooseName(rarityFolder, modelName)
			if template then
				return template
			end
		end
	end

	local template = root:FindFirstChild(modelName, true)
	if template and template:IsA('Model') then
		return template
	end
	return findModelByLooseName(root, modelName)
end

local function findBrainrotTemplate(name: string, rarity: string?): Model?
	return findBrainrotTemplateInRoot(NORMAL_BRAINROT_MODELS, name, rarity)
end

local function findMutatedBrainrotTemplate(name: string, rarity: string?, mutation: string?): Model?
	local mutationFolder: Instance? = nil
	if mutation and mutation ~= 'Normal' then
		mutationFolder = BRAINROT_MODELS:FindFirstChild(mutation) or findDirectChildByLooseName(BRAINROT_MODELS, mutation)
	end
	if mutationFolder then
		return findBrainrotTemplateInRoot(mutationFolder, name, rarity) or findBrainrotTemplate(name, rarity)
	end
	return findBrainrotTemplate(name, rarity)
end

local function findFirstActualBrainrotTemplate(root: Instance): Model?
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA('Model') then
			return child
		elseif child:IsA('Folder') and child.Name ~= 'RollingAnim' and child.Name ~= 'BillboardGuis' then
			local template = findFirstActualBrainrotTemplate(child)
			if template then
				return template
			end
		end
	end

	return nil
end

local function getTemplateCacheKey(name: string, rarity: string?, rolling: boolean, mutation: string?): string
	return tostring(rolling) .. '|' .. tostring(mutation or '') .. '|' .. tostring(rarity or '') .. '|' .. tostring(name)
end

local function preloadTemplate(template: Model?)
	if not template or PRELOADED_TEMPLATES[template] then
		return
	end

	PRELOADED_TEMPLATES[template] = true
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ template })
		end)
	end)
end

local function removeEmbeddedHighlights(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('Highlight') then
			descendant:Destroy()
		end
	end
end

local function getRollingHighlightTemplate(): Highlight?
	if ROLLING_HIGHLIGHT_TEMPLATE and ROLLING_HIGHLIGHT_TEMPLATE.Parent then
		return ROLLING_HIGHLIGHT_TEMPLATE
	end

	local direct = ROLLING_ANIM_BRAINROT_MODELS:FindFirstChild(ROLLING_HIGHLIGHT_NAME)
	if direct and direct:IsA('Highlight') then
		ROLLING_HIGHLIGHT_TEMPLATE = direct
		return direct
	end

	local descendant = ROLLING_ANIM_BRAINROT_MODELS:FindFirstChild(ROLLING_HIGHLIGHT_NAME, true)
	if descendant and descendant:IsA('Highlight') then
		ROLLING_HIGHLIGHT_TEMPLATE = descendant
		return descendant
	end

	return nil
end

local function getCameraFacingCFrame(position: Vector3): CFrame
	local camera = workspace.CurrentCamera
	if not camera then
		return CFrame.new(position)
	end

	local lookAt = Vector3.new(camera.CFrame.Position.X, position.Y, camera.CFrame.Position.Z)
	if (lookAt - position).Magnitude < 0.001 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, lookAt)
end

local function rotateAroundWorldAxis(baseCFrame: CFrame, axis: Vector3, angle: number): CFrame
	local position = baseCFrame.Position
	local rotation = baseCFrame - position
	return CFrame.new(position) * CFrame.fromAxisAngle(axis.Unit, angle) * rotation
end

local function getPerformanceScale(result: string?): number
	if result == 'Perfect' then
		return 1.35
	elseif result == 'Okay' then
		return 1
	end
	return 0.68
end

function MicrowaveClient:Create(session, microwaveService, setPowerUi, stopMicrowaveUi, onDone: (() -> ())?)
	self.Session = session
	self.Service = microwaveService
	self.SetPowerUi = setPowerUi
	self.StopMicrowaveUi = stopMicrowaveUi
	self.OnDone = onDone
	self.Microwave = session and session.Microwave
	self.Slot = session and session.Slot
	local minigameConfig = getMicrowaveMinigameConfig(self.Framework)
	local clientConfig = getMicrowaveClientConfig(self.Framework)
	self.CookTime = math.clamp(tonumber(session and session.CookTime) or minigameConfig.CookTime or DEFAULT_COOK_TIME, 1, 30)
	self.SetPowerSpeed = math.clamp(tonumber(session and session.SetPowerSpeed) or minigameConfig.SetPowerSpeed or 1.4, 0.25, 6)
	self.StopMicrowaveSpeed = math.clamp(tonumber(session and session.StopMicrowaveSpeed) or minigameConfig.StopMicrowaveSpeed or 1.7, 0.25, 6)
	self.RevealTime = clientConfig.RevealTime or DEFAULT_REVEAL_TIME
	self.RollTime = clientConfig.RollTime or DEFAULT_ROLL_TIME
	self.CameraTweenTime = clientConfig.CameraTweenTime or DEFAULT_CAMERA_TWEEN_TIME
	self.UiHandoffDelay = clientConfig.UiHandoffDelay or DEFAULT_UI_HANDOFF_DELAY
	self.StartCameraOffset = clientConfig.StartCameraOffset or DEFAULT_START_CAMERA_OFFSET
	self.CookCameraOffset = clientConfig.CookCameraOffset or DEFAULT_COOK_CAMERA_OFFSET
	self.RevealCameraOffset = clientConfig.RevealCameraOffset or DEFAULT_REVEAL_CAMERA_OFFSET
	self.FocusOffset = clientConfig.FocusOffset or DEFAULT_FOCUS_OFFSET
	self.CookColor = clientConfig.CookColor or DEFAULT_COOK_COLOR
	self.HotColor = clientConfig.HotColor or DEFAULT_HOT_COLOR
	self.RevealColor = clientConfig.RevealColor or DEFAULT_REVEAL_COLOR
	self.RarityColors = (getMicrowaveConfig(self.Framework).Roll and getMicrowaveConfig(self.Framework).Roll.RarityColors) or DEFAULT_RARITY_COLORS
	self.TrayNames = clientConfig.TrayNames or DEFAULT_TRAY_NAMES
	self.Camera = workspace.CurrentCamera
	self.PreviousCameraType = nil
	self.PreviousCameraSubject = nil
	self.PreviousFieldOfView = nil
	self._created = {}
	self._tweens = {}
	self._connections = {}
	self._running = false
	self._blockBaseCFrame = nil
	self._rewardBaseCFrame = nil
	self._trayBaseCFrame = nil
	self._rollingHighlight = nil
end

function MicrowaveClient:AddCreated(instance: Instance)
	table.insert(self._created, instance)
	return instance
end

function MicrowaveClient:SetRollingPreviewHighlight(model: Model?)
	local highlight = self._rollingHighlight
	if not highlight then
		local template = getRollingHighlightTemplate()
		if not template then
			return
		end

		highlight = template
		highlight.Enabled = false
		highlight.Adornee = nil
		self._rollingHighlight = highlight
	end

	highlight.Adornee = model
	highlight.Enabled = model ~= nil
end

function MicrowaveClient:AddTween(tween: Tween)
	table.insert(self._tweens, tween)
	tween:Play()
	return tween
end

function MicrowaveClient:DisconnectMotion()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

function MicrowaveClient:GetFocusCFrame(offset: Vector3, focusOffset: Vector3?): CFrame?
	if not self.Slot or not self.Slot:IsA('BasePart') then
		return nil
	end

	local focus = self.Slot.CFrame:PointToWorldSpace(focusOffset or self.FocusOffset or DEFAULT_FOCUS_OFFSET)
	local position = self.Slot.CFrame:PointToWorldSpace(offset)
	return CFrame.lookAt(position, focus)
end

function MicrowaveClient:GetStartCameraCFrame(): CFrame?
	local cframe = self:GetCameraPointCFrame('StartView')
	if cframe then
		return cframe
	end

	return self:GetFocusCFrame(self.StartCameraOffset or DEFAULT_START_CAMERA_OFFSET)
end

function MicrowaveClient:GetCameraPointCFrame(pointName: string): CFrame?
	local microwave = self.Microwave
	if microwave and microwave:IsA('Model') then
		local cameraPoints = microwave.Parent:FindFirstChild('CameraPoints', true)
		local point = cameraPoints and cameraPoints:FindFirstChild(pointName)
		if point and point:IsA('BasePart') then
			return point.CFrame
		end
	end

	return nil
end

function MicrowaveClient:TweenCamera(cframe: CFrame?, fieldOfView: number, duration: number, easingStyle: Enum.EasingStyle?)
	if not cframe then
		return
	end

	self.Camera.CameraType = Enum.CameraType.Scriptable
	self:AddTween(TweenService:Create(
		self.Camera,
		TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cframe, FieldOfView = fieldOfView }
		))
end

function MicrowaveClient:PrepareView()
	self.Camera = workspace.CurrentCamera
	self.PreviousCameraType = self.Camera.CameraType
	self.PreviousCameraSubject = self.Camera.CameraSubject
	self.PreviousFieldOfView = self.Camera.FieldOfView
	self:TweenCamera(self:GetStartCameraCFrame(), 58, self.CameraTweenTime or DEFAULT_CAMERA_TWEEN_TIME)
	task.wait((self.CameraTweenTime or DEFAULT_CAMERA_TWEEN_TIME) + (self.UiHandoffDelay or DEFAULT_UI_HANDOFF_DELAY))
end

function MicrowaveClient:RestoreView()
	local camera = workspace.CurrentCamera
	if self.PreviousCameraType then
		camera.CameraType = self.PreviousCameraType
	end
	if self.PreviousCameraSubject then
		camera.CameraSubject = self.PreviousCameraSubject
	end
	if self.PreviousFieldOfView then
		camera.FieldOfView = self.PreviousFieldOfView
	end
end

function MicrowaveClient:GetInsertedBlock(): Model?
	if self.Block and self.Block.Parent then
		return self.Block
	end

	if not self.Microwave or not self.Microwave:IsA('Model') then
		return nil
	end

	self.Block = getModelFromFolder(self.Microwave, 'InsertedLuckyblock')
	if self.Block then
		self._blockBaseCFrame = self.Block:GetPivot()
	end
	return self.Block
end

function MicrowaveClient:GetTray(): Instance?
	if self.Tray and self.Tray.Parent then
		return self.Tray
	end

	if not self.Microwave or not self.Microwave:IsA('Model') then
		return nil
	end

	for _, trayName in ipairs(self.TrayNames or DEFAULT_TRAY_NAMES) do
		local tray = self.Microwave:FindFirstChild(trayName, true)
		if tray and (tray:IsA('BasePart') or tray:IsA('Model')) then
			self.Tray = tray
			self._trayBaseCFrame = getPivot(tray)
			return tray
		end
	end

	return nil
end

function MicrowaveClient:GetRewardModel(result): Model?
	if result and result.RewardModel and result.RewardModel.Parent then
		self.RewardModel = result.RewardModel
	end

	if self.RewardModel and self.RewardModel.Parent then
		return self.RewardModel
	end

	local preview = result and result.RollPreview
	if type(preview) == 'table' then
		for index = #preview, 1, -1 do
			local entry = preview[index]
			if type(entry) == 'table' and entry.Winner == true then
				local template = self:GetRewardTemplate(entry)
				if template and template:IsA('Model') then
					local reward = self:AddCreated(template:Clone())
					reward.Name = tostring(entry.ModelName or entry.Name or 'MicrowaveReward')
					prepPreviewModel(reward)
					removeEmbeddedHighlights(reward)
					setLocalTransparency(reward, 1)
					setVisualEffectsEnabled(reward, false)
					reward.Parent = workspace
					reward:PivotTo(self:GetRollBaseCFrame(reward, self:GetRollAnchorCFrame(nil), 0))
					local billboard = BrainrotBillboard.Attach(reward, self.Framework, {
						Name = tostring(entry.Name or entry.ModelName or reward.Name),
						ModelName = tostring(entry.ModelName or reward.Name),
						Rarity = entry.Rarity,
						Mutation = entry.Mutation,
						BaseIncome = entry.BaseIncome,
					})
					if billboard then
						billboard.Enabled = false
					end
					self.RewardModel = reward
					return reward
				end
			end
		end
	end

	if not self.Microwave or not self.Microwave:IsA('Model') then
		return nil
	end

	self.RewardModel = getModelFromFolder(self.Microwave, 'MicrowaveResult')
	return self.RewardModel
end

function MicrowaveClient:CreateAttachmentEffects(rootPart: BasePart, name: string, color: Color3, rate: number, brightness: number)
	local attachment = self:AddCreated(Instance.new('Attachment'))
	attachment.Name = name .. 'Attachment'
	attachment.Parent = rootPart

	local light = self:AddCreated(Instance.new('PointLight'))
	light.Name = name .. 'Light'
	light.Color = color
	light.Brightness = brightness
	light.Range = 7 + brightness * 2
	light.Parent = rootPart

	local particles = self:AddCreated(Instance.new('ParticleEmitter'))
	particles.Name = name .. 'Particles'
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 0.75
	particles.Lifetime = NumberRange.new(0.25, 0.7)
	particles.Rate = rate
	particles.Speed = NumberRange.new(1.2, 3.4)
	particles.SpreadAngle = Vector2.new(75, 75)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.045),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = attachment

	return light, particles
end

function MicrowaveClient:CreateCookEffects(block: Model, powerPercent: number, powerResult: string?)
	local rootPart = getRootPart(block)
	if not rootPart then
		return
	end

	local performanceScale = getPerformanceScale(powerResult)
	local color = self.CookColor or DEFAULT_COOK_COLOR
	local intensity = math.clamp(powerPercent, 0, 1) * (0.72 + performanceScale * 0.18)
	local light, particles = self:CreateAttachmentEffects(rootPart, 'MicrowaveCook', color, 8 + intensity * 28, 0.8 + intensity * 2.1)
	self:AddTween(TweenService:Create(
		light,
		TweenInfo.new(math.max(0.12, 0.38 / performanceScale), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Brightness = light.Brightness * (1.18 + intensity * 0.38), Range = light.Range + 1.4 + intensity * 2 }
		))
	task.delay(self.CookTime * 0.72, function()
		if self._alive and particles.Parent then
			particles.Rate = particles.Rate * (if powerResult == 'Perfect' then 2.25 else 1.55)
			particles.Speed = NumberRange.new(2.5 * performanceScale, 6 * performanceScale)
		end
	end)

	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not self._alive or not light.Parent or not particles.Parent then
			connection:Disconnect()
			return
		end

		local progress = math.clamp((os.clock() - startedAt) / math.max(0.01, self.CookTime), 0, 1)
		local heatColor = (self.CookColor or DEFAULT_COOK_COLOR):Lerp(self.HotColor or DEFAULT_HOT_COLOR, math.clamp(progress * (0.8 + intensity * 0.8), 0, 1))
		light.Color = heatColor
		particles.Color = ColorSequence.new(heatColor)
		particles.Rate = (8 + intensity * 28) * (1 + progress * (0.3 + intensity * 0.75))
	end)
	table.insert(self._connections, connection)
end

function MicrowaveClient:Cook(powerPercent: number, powerResult: string?)
	local block = self:GetInsertedBlock()
	if not block or not self._blockBaseCFrame then
		return
	end

	local performanceScale = getPerformanceScale(powerResult)
	self:CreateCookEffects(block, powerPercent, powerResult)
	self:TweenCamera(self:GetCameraPointCFrame('CookView') or self:GetFocusCFrame(self.CookCameraOffset or DEFAULT_COOK_CAMERA_OFFSET), 51, self.CookTime, Enum.EasingStyle.Sine)

	local tray = self:GetTray()
	local startedAt = os.clock()
	local spinSpeed = (1.9 + powerPercent * 4.2) * performanceScale
	local traySpinSpeed = spinSpeed * 1.25
	local shakeAmount = (0.012 + powerPercent * 0.105) * performanceScale
	local bounceAmount = (0.035 + powerPercent * 0.18) * performanceScale
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not self._alive or not block.Parent then
			connection:Disconnect()
			return
		end

		local elapsed = os.clock() - startedAt
		local progress = math.clamp(elapsed / self.CookTime, 0, 1)
		local ramp = progress * progress
		local pulse = math.sin(elapsed * (10 + progress * 18) * performanceScale)
		local spin = CFrame.Angles(0, elapsed * spinSpeed * (1 + progress), 0)
		local stumble = if powerResult == 'Bad' then CFrame.Angles(math.sin(elapsed * 19) * 0.05 * ramp, 0, math.cos(elapsed * 23) * 0.04 * ramp) else CFrame.new()
		local shake = CFrame.new(
			math.sin(elapsed * 32) * shakeAmount * ramp,
			(math.abs(pulse) * bounceAmount + math.sin(elapsed * 5) * 0.015) * ramp,
			math.cos(elapsed * 27) * shakeAmount * ramp
		)
		block:PivotTo(self._blockBaseCFrame * shake * stumble * spin)

		if tray and tray.Parent and self._trayBaseCFrame then
			local spinAxis = if self.Slot and self.Slot:IsA('BasePart') then self.Slot.CFrame.UpVector else Vector3.yAxis
			pivotTo(tray, rotateAroundWorldAxis(self._trayBaseCFrame, spinAxis, elapsed * traySpinSpeed))
		end
	end)
	table.insert(self._connections, connection)
	task.wait(self.CookTime)
end

function MicrowaveClient:PlayStopImpact(_percent: number, stopResult: string?)
	self:TweenCamera(self:GetCameraPointCFrame('StopView') or self:GetFocusCFrame((self.CookCameraOffset or DEFAULT_COOK_CAMERA_OFFSET) + Vector3.new(0, 0, -0.25)), if stopResult == 'Perfect' then 45 else 49, 0.18, Enum.EasingStyle.Back)
	task.wait(0.22)
end

function MicrowaveClient:GetRarityColor(rarity: string?): Color3
	local colors = self.RarityColors or DEFAULT_RARITY_COLORS
	return colors[tostring(rarity or 'Common')] or colors.Common or DEFAULT_REVEAL_COLOR
end

function MicrowaveClient:GetRollBaseCFrame(model: Model, baseCFrame: CFrame, lift: number?): CFrame
	local _, size = model:GetBoundingBox()
	local position = baseCFrame.Position + Vector3.new(0, (size.Y * 0.5) + (lift or 0), 0)
	return getCameraFacingCFrame(position)
end

function MicrowaveClient:GetRollAnchorCFrame(reward: Model?): CFrame
	if self.Slot and self.Slot:IsA('BasePart') then
		return self.Slot.CFrame
	end

	if reward then
		local _, size = reward:GetBoundingBox()
		return reward:GetPivot() * CFrame.new(0, -size.Y * 0.5, 0)
	end

	return CFrame.new()
end

function MicrowaveClient:GetRollTemplate(entry): Model?
	local modelName = entry and (entry.ModelName or entry.Name)
	if type(modelName) ~= 'string' then
		return nil
	end
	local key = getTemplateCacheKey(modelName, entry.Rarity, true, entry.Mutation)
	if ROLL_TEMPLATE_CACHE[key] == nil then
		ROLL_TEMPLATE_CACHE[key] = findMutatedBrainrotTemplate(modelName, entry.Rarity, entry.Mutation) or false
		preloadTemplate(ROLL_TEMPLATE_CACHE[key])
	end
	return if ROLL_TEMPLATE_CACHE[key] ~= false then ROLL_TEMPLATE_CACHE[key] else nil
end

function MicrowaveClient:GetFallbackRollTemplate(): Model?
	if self._fallbackRollTemplate and self._fallbackRollTemplate.Parent then
		return self._fallbackRollTemplate
	end

	local template = findFirstActualBrainrotTemplate(BRAINROT_MODELS)
	if template then
		self._fallbackRollTemplate = template
		preloadTemplate(template)
		return template
	end

	return nil
end

function MicrowaveClient:GetRewardTemplate(entry): Model?
	local modelName = entry and (entry.ModelName or entry.Name)
	if type(modelName) ~= 'string' then
		return nil
	end
	local key = getTemplateCacheKey(modelName, entry.Rarity, false, entry.Mutation)
	if ROLL_TEMPLATE_CACHE[key] == nil then
		ROLL_TEMPLATE_CACHE[key] = findMutatedBrainrotTemplate(modelName, entry.Rarity, entry.Mutation) or false
		preloadTemplate(ROLL_TEMPLATE_CACHE[key])
	end
	return if ROLL_TEMPLATE_CACHE[key] ~= false then ROLL_TEMPLATE_CACHE[key] else nil
end

function MicrowaveClient:GetWarmupRollEntries()
	if self._warmupRollEntries then
		return self._warmupRollEntries
	end

	local entries = {}
	local function collectEntries(root: Instance, mutation: string?)
		for _, rarityFolder in ipairs(root:GetChildren()) do
			if rarityFolder:IsA('Folder') then
				for _, model in ipairs(rarityFolder:GetChildren()) do
					if model:IsA('Model') then
						table.insert(entries, {
							Name = model.Name,
							ModelName = model.Name,
							Rarity = rarityFolder.Name,
							Mutation = mutation,
						})
					end
				end
			elseif rarityFolder:IsA('Model') then
				table.insert(entries, {
					Name = rarityFolder.Name,
					ModelName = rarityFolder.Name,
					Rarity = 'Common',
					Mutation = mutation,
				})
			end
		end
	end
	local function containsRarityFolder(root: Instance): boolean
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA('Folder') and ROLL_RARITY_NAMES[child.Name] then
				return true
			end
		end
		return false
	end

	for _, child in ipairs(BRAINROT_MODELS:GetChildren()) do
		if child.Name == 'RollingAnim' or child.Name == 'BillboardGuis' then
			continue
		end

		if child:IsA('Folder') then
			local hasNestedModels = false
			for _, nested in ipairs(child:GetDescendants()) do
				if nested:IsA('Model') then
					hasNestedModels = true
					break
				end
			end

			if child.Name == 'Normal' then
				collectEntries(child, nil)
			elseif containsRarityFolder(child) and not ROLL_RARITY_NAMES[child.Name] then
				collectEntries(child, child.Name)
			elseif hasNestedModels then
				for _, model in ipairs(child:GetChildren()) do
					if model:IsA('Model') then
						table.insert(entries, {
							Name = model.Name,
							ModelName = model.Name,
							Rarity = child.Name,
							Mutation = nil,
						})
					end
				end
			end
		elseif child:IsA('Model') then
			table.insert(entries, {
				Name = child.Name,
				ModelName = child.Name,
				Rarity = 'Common',
			})
		end
	end

	if #entries == 0 then
		collectEntries(NORMAL_BRAINROT_MODELS, nil)
	end

	table.sort(entries, function(a, b)
		if a.Mutation ~= b.Mutation then
			return tostring(a.Mutation or '') < tostring(b.Mutation or '')
		end
		if a.Rarity == b.Rarity then
			return a.Name < b.Name
		end
		return a.Rarity < b.Rarity
	end)
	self._warmupRollEntries = entries
	for _, entry in ipairs(entries) do
		preloadTemplate(self:GetRollTemplate(entry))
	end
	return entries
end

function MicrowaveClient:PreloadRollPreview(preview)
	if type(preview) ~= 'table' then
		return
	end

	for _, entry in ipairs(preview) do
		if type(entry) == 'table' then
			preloadTemplate(if entry.Winner == true then self:GetRewardTemplate(entry) else self:GetRollTemplate(entry))
		end
	end
end

function MicrowaveClient:StartRollWarmup()
	local entries = self:GetWarmupRollEntries()
	if #entries == 0 then
		return function() end
	end

	local token = { Active = true, Model = nil }
	local baseCFrame = if self.Slot and self.Slot:IsA('BasePart') then self.Slot.CFrame else CFrame.new()

	task.spawn(function()
		local index = 0
		while self._alive and token.Active do
			index = (index % #entries) + 1
			if token.Model then
				self:SetRollingPreviewHighlight(nil)
				token.Model:Destroy()
				token.Model = nil
			end

			token.Model = self:CreateRollPreviewModel(entries[index], baseCFrame, index, #entries)
			local startedAt = os.clock()
			local stepTime = 0.045
			while self._alive and token.Active and os.clock() - startedAt < stepTime do
				if token.Model and token.Model.Parent then
					local elapsed = os.clock() - startedAt
					local stepProgress = math.clamp(elapsed / stepTime, 0, 1)
					local pop = math.sin(stepProgress * math.pi)
					token.Model:PivotTo(self:GetRollBaseCFrame(token.Model, baseCFrame, 0.08 + pop * 0.2))
				end
				RunService.RenderStepped:Wait()
			end
		end

		if token.Model then
			self:SetRollingPreviewHighlight(nil)
			token.Model:Destroy()
			token.Model = nil
		end
	end)

	return function()
		token.Active = false
		if token.Model then
			self:SetRollingPreviewHighlight(nil)
			token.Model:Destroy()
			token.Model = nil
		end
	end
end

function MicrowaveClient:CreateRollPreviewModel(entry, baseCFrame: CFrame, index: number, count: number): Model?
	local template = self:GetRollTemplate(entry) or self._lastRollPreviewTemplate or self:GetFallbackRollTemplate()
	if not template or not template:IsA('Model') then
		warn(('[MicrowaveClient] Missing rolling brainrot preview model for %s'):format(tostring(entry and (entry.ModelName or entry.Name) or '?')))
		return nil
	end
	self._lastRollPreviewTemplate = template

	local color = self:GetRarityColor(entry.Rarity)
	local model = template:Clone()
	model.Name = 'RollingPreview_' .. tostring(index)
	prepPreviewModel(model)
	removeEmbeddedHighlights(model)
	model.Parent = workspace
	model:PivotTo(self:GetRollBaseCFrame(model, baseCFrame, 0.1))
	BrainrotBillboard.Attach(model, self.Framework, {
		Name = tostring(entry.Name or entry.ModelName or model.Name),
		ModelName = tostring(entry.ModelName or entry.Name or model.Name),
		Rarity = entry.Rarity,
		Mutation = entry.Mutation,
		BaseIncome = entry.BaseIncome,
	})
	self:SetRollingPreviewHighlight(model)

	local rootPart = getRootPart(model)
	if rootPart then
		local _, particles = self:CreateAttachmentEffects(rootPart, 'MicrowaveRoll', color, 38, 3.6)
		particles.Lifetime = NumberRange.new(0.18, 0.46)
		particles.Speed = NumberRange.new(2.2, 5.8)
		particles:Emit(22)
	end

	return model
end

function MicrowaveClient:PlayRollPreview(result, reward: Model)
	self:SetRollingPreviewHighlight(nil)
	removeEmbeddedHighlights(reward)
	local preview = result and result.RollPreview
	if type(preview) ~= 'table' or #preview == 0 then
		return
	end
	self:PreloadRollPreview(preview)
	local rollEntries = {}
	for _, entry in ipairs(preview) do
		if type(entry) == 'table' and entry.Winner ~= true then
			table.insert(rollEntries, entry)
		end
	end
	if #rollEntries == 0 then
		return
	end

	self:TweenCamera(self:GetCameraPointCFrame('RevealView') or self:GetFocusCFrame(self.RevealCameraOffset or DEFAULT_REVEAL_CAMERA_OFFSET), 44, 0.32, Enum.EasingStyle.Back)
	setLocalTransparency(reward, 1)
	setVisualEffectsEnabled(reward, false)

	local baseCFrame = self:GetRollAnchorCFrame(reward)
	local count = #rollEntries
	local totalTime = math.max(0.75, tonumber(self.RollTime) or DEFAULT_ROLL_TIME)
	local currentModel: Model? = nil

	for index, entry in ipairs(rollEntries) do
		if not self._alive then
			break
		end

		if currentModel then
			self:SetRollingPreviewHighlight(nil)
			currentModel:Destroy()
			currentModel = nil
		end
		currentModel = self:CreateRollPreviewModel(entry, baseCFrame, index, count)

		local progress = index / count
		local easedProgress = progress * progress
		local stepTime = (totalTime / count) * (0.16 + easedProgress * 2.05)
		local startedAt = os.clock()
		while self._alive and os.clock() - startedAt < stepTime do
			local elapsed = os.clock() - startedAt
			local stepProgress = math.clamp(elapsed / stepTime, 0, 1)
			local pop = math.sin(stepProgress * math.pi)
			if currentModel and currentModel.Parent then
				currentModel:PivotTo(self:GetRollBaseCFrame(currentModel, baseCFrame, 0.08 + pop * (0.28 + progress * 0.12)))
			end
			RunService.RenderStepped:Wait()
		end
	end

	if currentModel then
		self:SetRollingPreviewHighlight(nil)
		currentModel:Destroy()
	end

	setLocalTransparency(reward, 0)
	setVisualEffectsEnabled(reward, true)
	self:SetRollingPreviewHighlight(nil)
	removeEmbeddedHighlights(reward)
	for _, descendant in ipairs(reward:GetDescendants()) do
		if descendant:IsA('BillboardGui') and descendant.Name == 'BrainrotBillboardGui' then
			descendant.Enabled = true
		end
	end
	self._rewardBaseCFrame = self:GetRollBaseCFrame(reward, baseCFrame, 0)
	reward:PivotTo(self._rewardBaseCFrame)
	local rewardColor = self:GetRarityColor(result and result.RewardRarity)
	local rootPart = getRootPart(reward)
	if rootPart then
		local burst = self:AddCreated(Instance.new('ParticleEmitter'))
		burst.Name = 'MicrowaveWinnerBurst'
		burst.Color = ColorSequence.new(rewardColor)
		burst.LightEmission = 1
		burst.Lifetime = NumberRange.new(0.32, 0.75)
		burst.Speed = NumberRange.new(5, 12)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.55, 0.08),
			NumberSequenceKeypoint.new(1, 0),
		})
		burst.Parent = rootPart
		burst:Emit(95)
	end

end

function MicrowaveClient:CreateRevealEffects(model: Model)
	local rootPart = getRootPart(model)
	if not rootPart then
		return
	end

	local light, particles = self:CreateAttachmentEffects(rootPart, 'MicrowaveReveal', self.RevealColor or DEFAULT_REVEAL_COLOR, 0, 4.5)
	particles.Lifetime = NumberRange.new(0.45, 0.9)
	particles.Speed = NumberRange.new(4, 8)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles:Emit(70)

	self:AddTween(TweenService:Create(
		light,
		TweenInfo.new(self.RevealTime or DEFAULT_REVEAL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0.4, Range = 6 }
		))

	local blur = self:AddCreated(Instance.new('BlurEffect'))
	blur.Name = 'MicrowaveRevealBlur'
	blur.Size = 6
	blur.Parent = Lighting
	self:AddTween(TweenService:Create(
		blur,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = 0 }
		))
end

function MicrowaveClient:Reveal(result)
	local reward = self:GetRewardModel(result)
	if not reward then
		return
	end

	self._rewardBaseCFrame = reward:GetPivot()
	self:PlayRollPreview(result, reward)
	self:CreateRevealEffects(reward)
	self:TweenCamera(self:GetCameraPointCFrame('RevealView') or self:GetFocusCFrame(self.RevealCameraOffset or DEFAULT_REVEAL_CAMERA_OFFSET), 47, 0.42, Enum.EasingStyle.Back)

	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not self._alive or not reward.Parent then
			connection:Disconnect()
			return
		end

		local elapsed = os.clock() - startedAt
		local progress = math.clamp(elapsed / (self.RevealTime or DEFAULT_REVEAL_TIME), 0, 1)
		local lift = math.sin(progress * math.pi) * 0.28
		local settle = math.sin(progress * math.pi * 2) * 0.035
		reward:PivotTo(self:GetRollBaseCFrame(reward, self:GetRollAnchorCFrame(reward), lift + settle))
	end)
	table.insert(self._connections, connection)
	task.wait(self.RevealTime or DEFAULT_REVEAL_TIME)
	self:DisconnectMotion()
	if reward.Parent and self._rewardBaseCFrame then
		reward:PivotTo(self._rewardBaseCFrame)
	end
end

function MicrowaveClient:Play()
	if self._running then
		return
	end
	self._running = true

	self:PrepareView()
	self.SetPowerUi:Play(function(powerPercent)
		local powerResponse = self.Service:SetPower(powerPercent)
		if not powerResponse or powerResponse.Ok ~= true then
			self:Finish()
			return
		end

		task.spawn(function()
			self:Cook(powerResponse.PowerPercent or powerPercent, powerResponse.PowerResult)
			if not self._alive then
				return
			end

			local beginResponse = self.Service:BeginStop()
			if not beginResponse or beginResponse.Ok ~= true then
				warn('[MicrowaveClient] Stop Microwave phase was rejected')
				self:Finish()
				return
			end

			self:TweenCamera(self:GetCameraPointCFrame('StopView') or self:GetFocusCFrame((self.CookCameraOffset or DEFAULT_COOK_CAMERA_OFFSET) + Vector3.new(0, 0, -0.15)), 49, 0.35, Enum.EasingStyle.Quad)
			self.StopMicrowaveUi:Play(function(stopPercent)
				self:DisconnectMotion()
				local stopWarmup = self:StartRollWarmup()
				local stopResponse = self.Service:StopMicrowave(stopPercent)
				stopWarmup()
				if not stopResponse or stopResponse.Ok ~= true then
					self:Finish()
					return
				end

				task.spawn(function()
					task.spawn(function()
						self:PlayStopImpact(stopPercent, stopResponse.StopResult)
					end)
					self:Reveal(stopResponse)
					self:Finish()
				end)
			end, self.StopMicrowaveSpeed)
		end)
	end, self.SetPowerSpeed)
end

function MicrowaveClient:Finish()
	if not self._alive then
		return
	end

	local response = self.Service:FinishMicrowave()
	if response and response.Ok ~= true then
		warn('[MicrowaveClient] Finish Microwave was rejected')
	end

	if self.OnDone then
		self.OnDone()
	end
	self:Destroy()
end

function MicrowaveClient:CleanUp()
	self:DisconnectMotion()
	self:SetRollingPreviewHighlight(nil)
	for _, tween in ipairs(self._tweens) do
		tween:Cancel()
	end
	table.clear(self._tweens)

	if self.Block and self.Block.Parent and self._blockBaseCFrame then
		self.Block:PivotTo(self._blockBaseCFrame)
	end
	if self.RewardModel and self.RewardModel.Parent and self._rewardBaseCFrame then
		self.RewardModel:PivotTo(self._rewardBaseCFrame)
	end
	if self.Tray and self.Tray.Parent and self._trayBaseCFrame then
		pivotTo(self.Tray, self._trayBaseCFrame)
	end

	for _, instance in ipairs(self._created) do
		instance:Destroy()
	end
	table.clear(self._created)
	self:RestoreView()
end

return MicrowaveClient
