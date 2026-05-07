local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local MicrowaveService = Framework:CreateService('MicrowaveService')

local MICROWAVE_MODEL_NAME = 'Microwave'
local MICROWAVE_PROMPT_NAME = 'MicrowavePrompt'
local SESSION_BLOCK_FOLDER_NAME = 'InsertedLuckyblock'
local LUCKYBLOCK_SLOT_NAME = 'LuckyblockSlot'
local INTERACT_DISTANCE_PADDING = 6

local function findAncestorModel(instance: Instance, modelName: string): Model?
	local current = instance
	while current and current ~= workspace do
		if current:IsA('Model') and current.Name == modelName then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function getPromptPart(prompt: ProximityPrompt): BasePart?
	return prompt.Parent and prompt.Parent:IsA('BasePart') and prompt.Parent or nil
end

local function prepInsertedBlock(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('WeldConstraint') then
			descendant:Destroy()
		elseif descendant:IsA('BasePart') then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = false
		end
	end
end

function MicrowaveService:Initialize()
	self.ActiveSessions = {}
end

function MicrowaveService:Start()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA('ProximityPrompt') and descendant.Name == MICROWAVE_PROMPT_NAME then
			descendant.Enabled = false
		end
	end
end

function MicrowaveService:GetBaseForPrompt(prompt: ProximityPrompt)
	local baseService = self.Framework:GetService('BaseService')
	for _, base in ipairs(baseService.Bases) do
		if prompt:IsDescendantOf(base.BaseFolder) then
			return base
		end
	end
	return nil
end

function MicrowaveService:IsPlayerNearPrompt(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local promptPart = getPromptPart(prompt)
	if not root or not root:IsA('BasePart') or not promptPart then
		return false
	end

	local maxDistance = prompt.MaxActivationDistance + INTERACT_DISTANCE_PADDING
	return (root.Position - promptPart.Position).Magnitude <= maxDistance
end

function MicrowaveService:GetOrCreateSlot(microwave: Model, prompt: ProximityPrompt): BasePart
	local existing = microwave:FindFirstChild(LUCKYBLOCK_SLOT_NAME, true)
	if existing and existing:IsA('BasePart') then
		return existing
	end

	local promptPart = getPromptPart(prompt)
	local _, microwaveSize = microwave:GetBoundingBox()
	local slot = Instance.new('Part')
	slot.Name = LUCKYBLOCK_SLOT_NAME
	slot.Size = Vector3.new(1, 1, 1)
	slot.Transparency = 1
	slot.Anchored = true
	slot.CanCollide = false
	slot.CanTouch = false
	slot.CanQuery = false
	slot.CFrame = (promptPart and promptPart.CFrame or microwave:GetPivot()) * CFrame.new(0, -microwaveSize.Y * 0.25, -1)
	slot.Parent = microwave
	return slot
end

function MicrowaveService:InsertLuckyblock(microwave: Model, prompt: ProximityPrompt, luckyblock: Model)
	local folder = microwave:FindFirstChild(SESSION_BLOCK_FOLDER_NAME)
	if not folder then
		folder = Instance.new('Folder')
		folder.Name = SESSION_BLOCK_FOLDER_NAME
		folder.Parent = microwave
	else
		folder:ClearAllChildren()
	end

	prepInsertedBlock(luckyblock)
	luckyblock.Parent = folder

	local slot = self:GetOrCreateSlot(microwave, prompt)
	local _, size = luckyblock:GetBoundingBox()
	luckyblock:PivotTo(slot.CFrame * CFrame.new(0, size.Y * 0.5, 0))
end

function MicrowaveService:CanStartOpening(player: Player, prompt: Instance)
	if self.ActiveSessions[player] then
		return false
	end

	if not prompt or not prompt:IsA('ProximityPrompt') or prompt.Name ~= MICROWAVE_PROMPT_NAME then
		return false
	end

	if not self:IsPlayerNearPrompt(player, prompt) then
		return false
	end

	local base = self:GetBaseForPrompt(prompt)
	if not base or base.Owner ~= player then
		return false
	end

	local microwave = findAncestorModel(prompt, MICROWAVE_MODEL_NAME)
	if not microwave then
		return false
	end

	return true, microwave
end

function MicrowaveService:StartOpening(player: Player, prompt: Instance)
	local canStart, microwave = self:CanStartOpening(player, prompt)
	if not canStart or not microwave then
		return { Ok = false }
	end

	local inventoryService = self.Framework:GetService('InventoryService')
	local luckyblock, luckyblockName = inventoryService:TakeEquippedLuckyblock(player)
	if not luckyblock then
		return { Ok = false }
	end

	self:InsertLuckyblock(microwave, prompt :: ProximityPrompt, luckyblock)

	local session = {
		Ok = true,
		StartTime = os.clock(),
		Phase = 'SetPower',
		LuckyblockName = luckyblockName,
		Microwave = microwave,
	}

	self.ActiveSessions[player] = session
	self.Framework:GetController('MicrowaveController').Server.Fire:ShowSetPower(player, session)
	return session
end

function MicrowaveService.Client:StartOpening(player: Player, prompt: Instance)
	return self:StartOpening(player, prompt)
end

return MicrowaveService
