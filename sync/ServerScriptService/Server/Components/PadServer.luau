local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local PadServer = BaseComponent:Extend('PadServer')

local BRAINROT_SLOT_NAME = 'BrainrotSlot'
local PAD_BRAINROT_FOLDER_NAME = 'PlacedBrainrot'
local PAD_OCCUPIED_ATTRIBUTE = 'PadOccupied'
local CLAIM_COOLDOWN = 0.5
local MONEY_UPDATE_INTERVAL = 0.25

local function getPadConfig(framework)
	return (framework and framework.Config and framework.Config.Pads) or {}
end

local function formatMoney(value: number): string
	value = math.max(0, math.floor(value))
	if value >= 1000000 then
		return ('$%.1fM'):format(value / 1000000):gsub('%.0M', 'M')
	elseif value >= 1000 then
		return ('$%.1fK'):format(value / 1000):gsub('%.0K', 'K')
	end
	return ('$%d'):format(value)
end

local function findBrainrotSlot(root: Instance): BasePart?
	local slot = root:FindFirstChild(BRAINROT_SLOT_NAME, true)
	if slot and slot:IsA('BasePart') then
		return slot
	end
	return nil
end

function PadServer:Create(padModel: Model, baseServer: any?, padIndex: number?)
	self.Model = padModel
	self.Base = baseServer
	self.Index = padIndex or tonumber(padModel.Name:match('%d+')) or 1
	self.VisibilityState = {}
	self.PressureButton = padModel:FindFirstChild('Money Display', true)
	self.MoneyDisplayLabel = self.PressureButton and self.PressureButton:FindFirstChildWhichIsA('TextLabel', true) or nil
	if self.MoneyDisplayLabel then
		self.MoneyDisplayLabel.Text = ''
	end
	self.CurrentBrainrot = nil
	self.CashToClaim = 0
	self.LastClaimAt = 0
	self.LastAccrueAt = os.clock()
	self.LastDisplayUpdateAt = 0
	self.TouchingPartsByPlayer = {}
	self.ClaimedThisTouchByPlayer = {}
	self.InteractPrompt = padModel:FindFirstChild('PadPrompt', true)
	self.BrainrotSlot = findBrainrotSlot(padModel)
	self.BrainrotFolder = padModel:FindFirstChild(PAD_BRAINROT_FOLDER_NAME) or Instance.new('Folder')
	self.BrainrotFolder.Name = PAD_BRAINROT_FOLDER_NAME
	self.BrainrotFolder.Parent = padModel
	self.BrainrotFolder:ClearAllChildren()
	self:SetEnabled(self:GetConfiguredEnabled())

	if self.InteractPrompt and self.InteractPrompt:IsA('ProximityPrompt') then
		self.InteractPrompt.Enabled = false
		self:AddConnection(self.InteractPrompt.Triggered:Connect(function(player)
			self:HandleInteract(player)
		end))
	end

	if self.PressureButton and self.PressureButton:IsA('BasePart') then
		self:AddConnection(self.PressureButton.Touched:Connect(function(part)
			self:HandleButtonTouched(part)
		end))
		self:AddConnection(self.PressureButton.TouchEnded:Connect(function(part)
			self:HandleButtonTouchEnded(part)
		end))
	end

	self:AddConnection(RunService.Heartbeat:Connect(function()
		self:UpdateCash()
	end))

	self:RefreshDisplay()
end

function PadServer:GetConfiguredEnabled(): boolean
	local config = getPadConfig(self.Framework)
	local unlockConfig = config.Unlocks and config.Unlocks[self.Index]
	if unlockConfig and type(unlockConfig.Enabled) == 'boolean' then
		return unlockConfig.Enabled
	end

	return self.Index <= (config.DefaultEnabledCount or math.huge)
end

function PadServer:GetEnabledAttributeName(): string
	return getPadConfig(self.Framework).EnabledAttribute or 'PadEnabled'
end

function PadServer:GetIndexAttributeName(): string
	return getPadConfig(self.Framework).IndexAttribute or 'PadIndex'
end

function PadServer:CaptureVisibilityState(descendant: Instance)
	if self.VisibilityState[descendant] then
		return self.VisibilityState[descendant]
	end

	local state = {}
	if descendant:IsA('BasePart') then
		state.Transparency = descendant.Transparency
		state.CanCollide = descendant.CanCollide
		state.CanTouch = descendant.CanTouch
		state.CanQuery = descendant.CanQuery
	elseif descendant:IsA('Decal') or descendant:IsA('Texture') then
		state.Transparency = descendant.Transparency
	elseif descendant:IsA('SurfaceGui') or descendant:IsA('BillboardGui') or descendant:IsA('ParticleEmitter') or descendant:IsA('Beam') then
		state.Enabled = descendant.Enabled
	end

	self.VisibilityState[descendant] = state
	return state
end

function PadServer:ApplyDescendantEnabled(descendant: Instance, enabled: boolean)
	local state = self:CaptureVisibilityState(descendant)
	if descendant:IsA('BasePart') then
		descendant.Transparency = if enabled then state.Transparency else 1
		descendant.CanCollide = if enabled then state.CanCollide else false
		descendant.CanTouch = if enabled then state.CanTouch else false
		descendant.CanQuery = if enabled then state.CanQuery else false
	elseif descendant:IsA('Decal') or descendant:IsA('Texture') then
		descendant.Transparency = if enabled then state.Transparency else 1
	elseif descendant:IsA('SurfaceGui') or descendant:IsA('BillboardGui') or descendant:IsA('ParticleEmitter') or descendant:IsA('Beam') then
		descendant.Enabled = if enabled then state.Enabled else false
	end
end

function PadServer:SetEnabled(enabled: boolean)
	self.Enabled = enabled == true
	self.Model:SetAttribute(self:GetEnabledAttributeName(), self.Enabled)
	self.Model:SetAttribute(self:GetIndexAttributeName(), self.Index)

	for _, descendant in ipairs(self.Model:GetDescendants()) do
		self:ApplyDescendantEnabled(descendant, self.Enabled)
	end

	if self.InteractPrompt and self.InteractPrompt:IsA('ProximityPrompt') then
		self.InteractPrompt:SetAttribute(self:GetEnabledAttributeName(), self.Enabled)
		self.InteractPrompt.Enabled = false
	end

	if not self.Enabled then
		self:Reset()
	end
	self:RefreshDisplay()
end

function PadServer:IsEnabled(): boolean
	return self.Enabled == true
end

function PadServer:IsOwner(player: Player): boolean
	return not self.Base or self.Base.Owner == player
end

function PadServer:RefreshDisplay()
	local occupied = self.CurrentBrainrot ~= nil
	self.Model:SetAttribute(PAD_OCCUPIED_ATTRIBUTE, occupied)
	if self.InteractPrompt and self.InteractPrompt:IsA('ProximityPrompt') then
		self.InteractPrompt:SetAttribute(PAD_OCCUPIED_ATTRIBUTE, occupied)
	end

	if not self.MoneyDisplayLabel then
		return
	end

	if not self:IsEnabled() or not occupied then
		self.MoneyDisplayLabel.Text = ''
		return
	end

	self.MoneyDisplayLabel.Text = formatMoney(self.CashToClaim)
end

function PadServer:UpdateCash()
	local now = os.clock()
	local elapsed = now - (self.LastAccrueAt or now)
	self.LastAccrueAt = now

	if self:IsEnabled() and self.CurrentBrainrot then
		local moneyPerSecond = tonumber(self.CurrentBrainrot.MoneyPerSecond) or 0
		self.CashToClaim += moneyPerSecond * math.max(0, elapsed)
	end

	if now - self.LastDisplayUpdateAt >= MONEY_UPDATE_INTERVAL then
		self.LastDisplayUpdateAt = now
		self:RefreshDisplay()
	end
end

function PadServer:GetPlayerFromPart(part: Instance): Player?
	local character = part:FindFirstAncestorOfClass('Model')
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

function PadServer:HandleButtonTouched(part: Instance)
	if not self:IsEnabled() then
		return
	end

	local player = self:GetPlayerFromPart(part)
	if not player then
		return
	end

	local touchingParts = self.TouchingPartsByPlayer[player]
	if not touchingParts then
		touchingParts = {}
		self.TouchingPartsByPlayer[player] = touchingParts
	end
	if touchingParts[part] then
		return
	end

	touchingParts[part] = true
	if self.ClaimedThisTouchByPlayer[player] ~= true then
		self:ClaimCash(player)
	end
end

function PadServer:HandleButtonTouchEnded(part: Instance)
	if not self:IsEnabled() then
		return
	end

	local player = self:GetPlayerFromPart(part)
	if not player then
		return
	end

	local touchingParts = self.TouchingPartsByPlayer[player]
	if not touchingParts then
		return
	end

	touchingParts[part] = nil
	if next(touchingParts) == nil then
		self.TouchingPartsByPlayer[player] = nil
		self.ClaimedThisTouchByPlayer[player] = nil
	end
end

function PadServer:ClaimCash(player: Player)
	if not self:IsEnabled() or not player or not self:IsOwner(player) or self.CashToClaim <= 0 then
		return false
	end

	local now = os.clock()
	if now - self.LastClaimAt < CLAIM_COOLDOWN then
		return false
	end
	self.LastClaimAt = now

	local amount = math.floor(self.CashToClaim)
	if amount <= 0 then
		return false
	end

	local dataService = self.Framework:GetService('DataService')
	if not dataService:AddPlayerData(player.UserId, 'Cash', amount) then
		return false
	end

	self.CashToClaim -= amount
	if self.CurrentBrainrot and self.CurrentBrainrot.PlayCollectJump then
		self.CurrentBrainrot:PlayCollectJump()
	end
	self.ClaimedThisTouchByPlayer[player] = true
	self:RefreshDisplay()
	return true
end

function PadServer:PlaceBrainrot(player: Player)
	if not self:IsEnabled() or self.CurrentBrainrot or not self.BrainrotSlot then
		return false
	end

	local inventoryService = self.Framework:GetService('InventoryService')
	local brainrotModel = inventoryService:TakeEquippedItem(player, 'Brainrot')
	if not brainrotModel then
		return false
	end

	self.BrainrotFolder:ClearAllChildren()
	brainrotModel.Parent = self.BrainrotFolder
	self.CurrentBrainrot = self.Framework.Components.BrainrotServer:new(brainrotModel, self.BrainrotSlot)
	self.LastAccrueAt = os.clock()
	self:RefreshDisplay()
	return true
end

function PadServer:ReturnExtractedBrainrot(player: Player, content): boolean
	local model = content and content.Model
	if not model or not model:IsA('Model') then
		return false
	end

	local snapshot = self.Framework:GetService('InventoryService'):AddItem(player, model, 'Brainrot', model.Name)
	if not snapshot then
		return false
	end

	local cashToClaim = math.floor(tonumber(content.CashToClaim) or 0)
	if cashToClaim > 0 then
		self.Framework:GetService('DataService'):AddPlayerData(player.UserId, 'Cash', cashToClaim)
	end

	model:Destroy()
	return true
end

function PadServer:PickupBrainrot(player: Player)
	if not self:IsEnabled() or not self.CurrentBrainrot then
		return false
	end

	local content = self:ExtractPlacedBrainrot()
	if not content then
		return false
	end

	if self:ReturnExtractedBrainrot(player, content) then
		return true
	end

	self:RestorePlacedBrainrot(content.Model, content.CashToClaim)
	return false
end

function PadServer:ReplaceBrainrot(player: Player)
	if not self:IsEnabled() or not self.CurrentBrainrot or not self.BrainrotSlot then
		return false
	end

	local inventoryService = self.Framework:GetService('InventoryService')
	local newBrainrotModel = inventoryService:TakeEquippedItem(player, 'Brainrot')
	if not newBrainrotModel then
		return false
	end

	local oldContent = self:ExtractPlacedBrainrot()
	if not oldContent then
		inventoryService:AddItem(player, newBrainrotModel, 'Brainrot', newBrainrotModel.Name)
		newBrainrotModel:Destroy()
		return false
	end

	self.BrainrotFolder:ClearAllChildren()
	newBrainrotModel.Parent = self.BrainrotFolder
	self.CurrentBrainrot = self.Framework.Components.BrainrotServer:new(newBrainrotModel, self.BrainrotSlot)
	self.CashToClaim = 0
	self.LastAccrueAt = os.clock()
	if not self:ReturnExtractedBrainrot(player, oldContent) then
		local newContent = self:ExtractPlacedBrainrot()
		self:RestorePlacedBrainrot(oldContent.Model, oldContent.CashToClaim)
		if newContent then
			self:ReturnExtractedBrainrot(player, newContent)
		end
		return false
	end

	self:RefreshDisplay()
	return true
end

function PadServer:ExtractPlacedBrainrot()
	if not self.CurrentBrainrot or not self.CurrentBrainrot.Model then
		return nil
	end

	local model = self.CurrentBrainrot.Model
	local cashToClaim = self.CashToClaim
	self.CurrentBrainrot.Model = nil
	self.CurrentBrainrot:Destroy()
	self.CurrentBrainrot = nil
	model.Parent = nil
	self.BrainrotFolder:ClearAllChildren()
	self.CashToClaim = 0
	table.clear(self.TouchingPartsByPlayer)
	table.clear(self.ClaimedThisTouchByPlayer)
	self:RefreshDisplay()

	return {
		Model = model,
		CashToClaim = cashToClaim,
	}
end

function PadServer:RestorePlacedBrainrot(model: Model, cashToClaim: number?)
	if not self:IsEnabled() or self.CurrentBrainrot or not self.BrainrotSlot or not model then
		return false
	end

	self.BrainrotFolder:ClearAllChildren()
	model.Parent = self.BrainrotFolder
	self.CurrentBrainrot = self.Framework.Components.BrainrotServer:new(model, self.BrainrotSlot)
	self.CashToClaim = math.max(0, tonumber(cashToClaim) or 0)
	self.LastAccrueAt = os.clock()
	self:RefreshDisplay()
	return true
end

function PadServer:HandleInteract(player: Player)
	if not self:IsEnabled() or not player or not self:IsOwner(player) then
		return
	end

	local inventoryService = self.Framework:GetService('InventoryService')
	if inventoryService.IsInventoryLocked and inventoryService:IsInventoryLocked(player) then
		return
	end

	if not self.CurrentBrainrot then
		self:PlaceBrainrot(player)
		return
	end

	local equippedItem = inventoryService:GetEquippedItem(player)
	if equippedItem and equippedItem.ItemType == 'Brainrot' then
		self:ReplaceBrainrot(player)
	else
		self:PickupBrainrot(player)
	end
end

function PadServer:Reset()
	if self.CurrentBrainrot then
		self.CurrentBrainrot:Destroy()
		self.CurrentBrainrot = nil
	end
	self.BrainrotFolder:ClearAllChildren()
	self.CashToClaim = 0
	table.clear(self.TouchingPartsByPlayer)
	table.clear(self.ClaimedThisTouchByPlayer)
	self:RefreshDisplay()
end

function PadServer:CleanUp()
	self:Reset()
end


return PadServer
