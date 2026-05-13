local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)
local BrainrotBillboard = require(game:GetService('ReplicatedStorage'):WaitForChild('Shared').Utils:WaitForChild('BrainrotBillboard'))

local Players = game:GetService('Players')

local InventoryService = Framework:CreateService('InventoryService')

local LEGACY_EQUIP_WELD_NAME = 'InventoryEquipWeld'
local HAND_WELD_NAME = 'InventoryHandWeld'
local ASSEMBLY_WELD_NAME = 'InventoryAssemblyWeld'
local DEFAULT_ITEM_TYPE_ATTRIBUTE = 'ItemType'
local DEFAULT_EQUIP_OFFSET = CFrame.new(0, -0.75, -1) * CFrame.Angles(0, math.rad(90), 0)
local DEFAULT_BRAINROT_HOLD_OFFSET = Vector3.new(0, -0.15, -0.65)
local DEFAULT_BRAINROT_HOLD_ROTATION = Vector3.new(0, 0, 0)
local DEFAULT_LUCKYBLOCK_HOLD_PADDING = 0.65
local DEFAULT_LUCKYBLOCK_HOLD_Y_OFFSET = -0.2
local PART_CACHE_BY_MODEL = setmetatable({}, { __mode = 'k' })
local MODEL_META_BY_MODEL = setmetatable({}, { __mode = 'k' })

local function getInventoryConfig(framework)
	return (framework and framework.Config and framework.Config.Inventory) or {}
end

local function getBaseParts(model: Model)
	local cached = PART_CACHE_BY_MODEL[model]
	if cached then
		return cached
	end

	local parts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BasePart') then
			table.insert(parts, descendant)
		end
	end
	PART_CACHE_BY_MODEL[model] = parts
	return parts
end

local function getModelMeta(model: Model)
	local cached = MODEL_META_BY_MODEL[model]
	if cached then
		return cached
	end

	local boundingBoxCFrame, size = model:GetBoundingBox()
	local rootPart = model.PrimaryPart
	local meta = {
		BoundingSize = size,
		BoundingPivotOffset = boundingBoxCFrame:ToObjectSpace(model:GetPivot()),
		LuckyblockRadius = math.max(size.X, size.Z) * 0.5,
		RootPart = rootPart,
	}
	MODEL_META_BY_MODEL[model] = meta
	return meta
end

local function getFirstBasePart(model: Model): BasePart?
	local meta = MODEL_META_BY_MODEL[model]
	if meta and meta.RootPart and meta.RootPart.Parent then
		return meta.RootPart
	end

	if model.PrimaryPart then
		if meta then
			meta.RootPart = model.PrimaryPart
		end
		return model.PrimaryPart
	end

	local centerCube = model:FindFirstChild('CenterCube', true)
	if centerCube and centerCube:IsA('BasePart') then
		model.PrimaryPart = centerCube
		meta = meta or getModelMeta(model)
		meta.RootPart = centerCube
		return centerCube
	end

	meta = meta or getModelMeta(model)
	for _, part in ipairs(getBaseParts(model)) do
		if part.Parent then
			model.PrimaryPart = part
			meta.RootPart = part
			return part
		end
	end
	return nil
end

local function getEquipPart(character: Model): BasePart?
	return character:FindFirstChild('RightHand') :: BasePart?
		or character:FindFirstChild('Right Arm') :: BasePart?
		or character:FindFirstChild('HumanoidRootPart') :: BasePart?
end

local function getLuckyblockEquipPart(character: Model): BasePart?
	return character:FindFirstChild('UpperTorso') :: BasePart?
		or character:FindFirstChild('Torso') :: BasePart?
		or character:FindFirstChild('HumanoidRootPart') :: BasePart?
end

local function getNumberAttribute(instance: Instance, name: string, defaultValue: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == 'number' then value else defaultValue
end

local function getLuckyblockEquipPivot(holdPart: BasePart, model: Model, holdConfig): CFrame
	local offsetAttributes = holdConfig.HoldOffsetAttributes or {}
	local rotationAttributes = holdConfig.HoldRotationAttributes or {}
	local meta = getModelMeta(model)
	local pivotOffset = meta.BoundingPivotOffset
	local radius = meta.LuckyblockRadius
	local xOffset = getNumberAttribute(model, offsetAttributes.X or 'HoldOffsetX', 0)
	local yOffset = getNumberAttribute(model, offsetAttributes.Y or 'HoldOffsetY', holdConfig.HoldOffsetY or DEFAULT_LUCKYBLOCK_HOLD_Y_OFFSET)
	local zPadding = getNumberAttribute(model, offsetAttributes.Padding or 'HoldPadding', holdConfig.HoldPadding or DEFAULT_LUCKYBLOCK_HOLD_PADDING)
	local xRotation = math.rad(getNumberAttribute(model, rotationAttributes.X or 'HoldRotationX', 0))
	local yRotation = math.rad(getNumberAttribute(model, rotationAttributes.Y or 'HoldRotationY', 0))
	local zRotation = math.rad(getNumberAttribute(model, rotationAttributes.Z or 'HoldRotationZ', 0))
	local centerOffset = CFrame.new(xOffset, yOffset, -(radius + zPadding))
		* CFrame.Angles(xRotation, yRotation, zRotation)

	return holdPart.CFrame * centerOffset * pivotOffset
end

local function getCharacterForwardCFrame(character: Model?, fallbackPart: BasePart, position: Vector3): CFrame
	local rootPart = character and character:FindFirstChild('HumanoidRootPart')
	local forward = if rootPart and rootPart:IsA('BasePart') then rootPart.CFrame.LookVector else fallbackPart.CFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude < 0.001 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	return CFrame.lookAt(position, position + forward, Vector3.yAxis)
end

local function getBrainrotEquipPivot(holdPart: BasePart, model: Model, character: Model?, holdConfig): CFrame
	local primaryPart = getFirstBasePart(model)
	if not primaryPart then
		return model:GetPivot()
	end

	local offsetAttributes = holdConfig.HoldOffsetAttributes or {}
	local rotationAttributes = holdConfig.HoldRotationAttributes or {}
	local defaultOffset = holdConfig.HoldOffset or DEFAULT_BRAINROT_HOLD_OFFSET
	local defaultRotation = holdConfig.HoldRotation or DEFAULT_BRAINROT_HOLD_ROTATION
	local xOffset = getNumberAttribute(model, offsetAttributes.X or 'BrainrotHoldOffsetX', defaultOffset.X)
	local yOffset = getNumberAttribute(model, offsetAttributes.Y or 'BrainrotHoldOffsetY', defaultOffset.Y)
	local zOffset = getNumberAttribute(model, offsetAttributes.Z or 'BrainrotHoldOffsetZ', defaultOffset.Z)
	local xRotation = math.rad(getNumberAttribute(model, rotationAttributes.X or 'BrainrotHoldRotationX', defaultRotation.X))
	local yRotation = math.rad(getNumberAttribute(model, rotationAttributes.Y or 'BrainrotHoldRotationY', defaultRotation.Y))
	local zRotation = math.rad(getNumberAttribute(model, rotationAttributes.Z or 'BrainrotHoldRotationZ', defaultRotation.Z))
	local facingCFrame = getCharacterForwardCFrame(character, holdPart, holdPart.Position)
	local targetPrimaryCFrame = facingCFrame * CFrame.new(xOffset, yOffset, zOffset) * CFrame.Angles(xRotation, yRotation, zRotation)
	local pivotOffset = primaryPart.CFrame:ToObjectSpace(model:GetPivot())

	return targetPrimaryCFrame * pivotOffset
end

local function getEquipPivot(equipPart: BasePart, model: Model, itemType: string, inventoryConfig, character: Model?): CFrame
	if itemType == 'Luckyblock' then
		return getLuckyblockEquipPivot(equipPart, model, inventoryConfig.LuckyblockHold or {})
	elseif itemType == 'Brainrot' then
		return getBrainrotEquipPivot(equipPart, model, character, inventoryConfig.BrainrotHold or {})
	end

	return equipPart.CFrame * (inventoryConfig.DefaultEquipOffset or DEFAULT_EQUIP_OFFSET)
end

local function hasAssemblyWeld(rootPart: BasePart, part: BasePart): boolean
	for _, child in ipairs(rootPart:GetChildren()) do
		if child:IsA('WeldConstraint')
			and child.Name == ASSEMBLY_WELD_NAME
			and ((child.Part0 == rootPart and child.Part1 == part) or (child.Part0 == part and child.Part1 == rootPart))
		then
			return true
		end
	end

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA('WeldConstraint')
			and child.Name == ASSEMBLY_WELD_NAME
			and ((child.Part0 == rootPart and child.Part1 == part) or (child.Part0 == part and child.Part1 == rootPart))
		then
			return true
		end
	end

	return false
end

local function ensureRigidInventoryAssembly(model: Model, rootPart: BasePart)
	local meta = getModelMeta(model)
	if meta.InventoryAssemblyPrepped then
		return
	end
	meta.InventoryAssemblyPrepped = true

	for _, part in ipairs(getBaseParts(model)) do
		if part.Parent and part ~= rootPart and not hasAssemblyWeld(rootPart, part) then
			local weld = Instance.new('WeldConstraint')
			weld.Name = ASSEMBLY_WELD_NAME
			weld.Part0 = rootPart
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function prepInventoryModel(model: Model, _equipped: boolean, itemType: string?)
	local meta = getModelMeta(model)
	if not meta.InventoryPrepped then
		meta.InventoryPrepped = true

		for _, part in ipairs(getBaseParts(model)) do
			if part.Parent then
				part.Anchored = false
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
			end
		end
	end

	local rootPart = getFirstBasePart(model)
	if rootPart then
		ensureRigidInventoryAssembly(model, rootPart)
	end
end

local function setModelNetworkOwner(model: Model, owner: Player?)
	return
end

local function removeNamedWelds(rootPart: BasePart, weldName: string)
	for _, child in ipairs(rootPart:GetChildren()) do
		if child:IsA('WeldConstraint') and child.Name == weldName then
			child:Destroy()
		end
	end
end

local function clearEquipWeld(model: Model, rootPart: BasePart?)
	if rootPart and rootPart.Parent then
		removeNamedWelds(rootPart, HAND_WELD_NAME)
		removeNamedWelds(rootPart, LEGACY_EQUIP_WELD_NAME)
		return
	end

	for _, part in ipairs(getBaseParts(model)) do
		if part.Parent then
			removeNamedWelds(part, HAND_WELD_NAME)
			removeNamedWelds(part, LEGACY_EQUIP_WELD_NAME)
		end
	end
end

local function weldModelToPart(model: Model, rootPart: BasePart, equipPart: BasePart)
	clearEquipWeld(model, rootPart)
	local equipWeld = Instance.new('WeldConstraint')
	equipWeld.Name = HAND_WELD_NAME
	equipWeld.Part0 = equipPart
	equipWeld.Part1 = rootPart
	equipWeld.Parent = rootPart
end

local function isInventoryModel(instance: Instance): boolean
	return instance:IsA('Model')
end

local function sortItemsBySlot(items)
	table.sort(items, function(a, b)
		return (a.Slot or math.huge) < (b.Slot or math.huge)
	end)
end

function InventoryService:Initialize()
	self.ItemsByPlayer = {}
	self.ItemsByModelByPlayer = {}
	self.ConnectionsByPlayer = {}
	self.CharacterConnectionsByPlayer = {}
	self.SuppressRefreshByPlayer = {}
	self.InventoryLockedByPlayer = {}
end

function InventoryService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:TrackPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:TrackPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:UntrackPlayer(player)
	end)
end

function InventoryService:TrackPlayer(player: Player)
	if self.ConnectionsByPlayer[player] then
		return
	end

	self.ItemsByPlayer[player] = {}
	self.ItemsByModelByPlayer[player] = {}
	self.ConnectionsByPlayer[player] = {}
	local backpack = player:WaitForChild('Backpack')

	table.insert(self.ConnectionsByPlayer[player], backpack.ChildAdded:Connect(function(child)
		if isInventoryModel(child) and not self:IsRefreshSuppressed(player) then
			self:RefreshPlayer(player)
		end
	end))

	table.insert(self.ConnectionsByPlayer[player], backpack.ChildRemoved:Connect(function(child)
		if isInventoryModel(child) and not self:IsRefreshSuppressed(player) then
			self:RefreshPlayer(player)
		end
	end))

	table.insert(self.ConnectionsByPlayer[player], player.CharacterAdded:Connect(function(character)
		self:BindCharacter(player, character)
		self:RefreshPlayer(player)
	end))

	if player.Character then
		self:BindCharacter(player, player.Character)
	end

	self:RefreshPlayer(player)
end

function InventoryService:BindCharacter(player: Player, character: Model)
	local oldConnections = self.CharacterConnectionsByPlayer[player]
	if oldConnections then
		for _, connection in ipairs(oldConnections) do
			connection:Disconnect()
		end
	end

	local connections = {}
	self.CharacterConnectionsByPlayer[player] = connections

	table.insert(connections, character.ChildAdded:Connect(function(child)
		if isInventoryModel(child) and not self:IsRefreshSuppressed(player) then
			self:RefreshPlayer(player)
		end
	end))

	table.insert(connections, character.ChildRemoved:Connect(function(child)
		if isInventoryModel(child) and not self:IsRefreshSuppressed(player) then
			self:RefreshPlayer(player)
		end
	end))
end

function InventoryService:IsRefreshSuppressed(player: Player): boolean
	return (self.SuppressRefreshByPlayer[player] or 0) > 0
end

function InventoryService:WithSuppressedRefresh(player: Player, callback)
	self.SuppressRefreshByPlayer[player] = (self.SuppressRefreshByPlayer[player] or 0) + 1
	local ok, result = pcall(callback)
	self.SuppressRefreshByPlayer[player] = math.max(0, (self.SuppressRefreshByPlayer[player] or 1) - 1)
	if self.SuppressRefreshByPlayer[player] == 0 then
		self.SuppressRefreshByPlayer[player] = nil
	end
	if not ok then
		error(result, 2)
	end
	return result
end

function InventoryService:UntrackPlayer(player: Player)
	local connections = self.ConnectionsByPlayer[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	local characterConnections = self.CharacterConnectionsByPlayer[player]
	if characterConnections then
		for _, connection in ipairs(characterConnections) do
			connection:Disconnect()
		end
	end

	for _, item in ipairs(self.ItemsByPlayer[player] or {}) do
		item:Destroy()
	end

	self.ItemsByPlayer[player] = nil
	self.ItemsByModelByPlayer[player] = nil
	self.ConnectionsByPlayer[player] = nil
	self.CharacterConnectionsByPlayer[player] = nil
	self.SuppressRefreshByPlayer[player] = nil
	self.InventoryLockedByPlayer[player] = nil
end

function InventoryService:SetInventoryLocked(player: Player, locked: boolean)
	if locked then
		self.InventoryLockedByPlayer[player] = true
	else
		self.InventoryLockedByPlayer[player] = nil
	end
end

function InventoryService:IsInventoryLocked(player: Player): boolean
	return self.InventoryLockedByPlayer[player] == true
end

function InventoryService:GetContainers(player: Player)
	return player:FindFirstChildOfClass('Backpack'), player.Character
end

function InventoryService:GetItemFromModel(player: Player, model: Instance)
	if not isInventoryModel(model) then
		return nil
	end

	local itemsByModel = self.ItemsByModelByPlayer[player]
	if itemsByModel and itemsByModel[model] then
		return itemsByModel[model]
	end

	for _, item in ipairs(self.ItemsByPlayer[player] or {}) do
		if item.Model == model then
			if itemsByModel then
				itemsByModel[model] = item
			end
			return item
		end
	end
	return nil
end

function InventoryService:GetItemType(model: Instance): string
	local itemTypeAttribute = getInventoryConfig(self.Framework).ItemTypeAttribute or DEFAULT_ITEM_TYPE_ATTRIBUTE
	local itemType = model:GetAttribute(itemTypeAttribute)
	if type(itemType) == 'string' and itemType ~= '' then
		return itemType
	end
	return model.Name
end

function InventoryService:GetItemClass()
	return self.Framework.Components.InventoryItemServer
end

function InventoryService:CreateItemFromModel(model: Model, equipped: boolean)
	local itemType = self:GetItemType(model)
	model:SetAttribute(getInventoryConfig(self.Framework).ItemTypeAttribute or DEFAULT_ITEM_TYPE_ATTRIBUTE, itemType)
	prepInventoryModel(model, equipped, itemType)
	return self:GetItemClass():new(model, itemType)
end

function InventoryService:SyncPlayerItems(player: Player)
	local backpack, character = self:GetContainers(player)
	local items = self.ItemsByPlayer[player]
	if not items then
		items = {}
		self.ItemsByPlayer[player] = items
	end
	local itemsByModel = self.ItemsByModelByPlayer[player]
	if not itemsByModel then
		itemsByModel = {}
		self.ItemsByModelByPlayer[player] = itemsByModel
	end

	local ownedModels = {}
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if isInventoryModel(child) then
				ownedModels[child] = true
				if not itemsByModel[child] then
					local item = self:CreateItemFromModel(child :: Model, false)
					if item then
						itemsByModel[child] = item
						table.insert(items, item)
					end
				end
			end
		end
	end
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if isInventoryModel(child) then
				ownedModels[child] = true
				if not itemsByModel[child] then
					local item = self:CreateItemFromModel(child :: Model, true)
					if item then
						itemsByModel[child] = item
						table.insert(items, item)
					end
				end
			end
		end
	end

	for index = #items, 1, -1 do
		local model = items[index].Model
		if not ownedModels[model] then
			itemsByModel[items[index].Model] = nil
			items[index]:Destroy()
			table.remove(items, index)
		end
	end
end

function InventoryService:GetItemAtSlot(player: Player, slot: number)
	return self:GetItemAtSlotNoSync(player, slot)
end

function InventoryService:GetItemAtSlotNoSync(player: Player, slot: number)
	local backpack, character = self:GetContainers(player)
	for _, item in ipairs(self.ItemsByPlayer[player] or {}) do
		if item.Slot == slot and item:IsOwnedBy(backpack, character) then
			return item
		end
	end
	return nil
end

function InventoryService:GetEquippedItem(player: Player)
	return self:GetEquippedItemNoSync(player)
end

function InventoryService:GetEquippedItemNoSync(player: Player)
	local _, character = self:GetContainers(player)
	if not character then
		return nil
	end

	for _, item in ipairs(self.ItemsByPlayer[player] or {}) do
		if item:IsEquipped(character) then
			return item
		end
	end
	return nil
end

function InventoryService:TakeEquippedItem(player: Player, itemType: string?)
	local item = self:GetEquippedItem(player)
	if not item or (itemType and item.ItemType ~= itemType) then
		return nil
	end

	local items = self.ItemsByPlayer[player]
	local index = items and table.find(items, item)
	if not items or not index then
		return nil
	end

	local model = item.Model
	local itemName = model.Name
	local removedItemType = item.ItemType
	local rootPart = getFirstBasePart(model)
	clearEquipWeld(model, rootPart)
	prepInventoryModel(model, false, removedItemType)
	setModelNetworkOwner(model, nil)
	table.remove(items, index)
	local itemsByModel = self.ItemsByModelByPlayer[player]
	if itemsByModel then
		itemsByModel[model] = nil
	end
	item:Destroy()
	model.Parent = nil
	self:RefreshPlayer(player)

	return model, itemName, removedItemType
end

function InventoryService:GetSnapshot(player: Player, skipSync: boolean?)
	if not skipSync then
		self:SyncPlayerItems(player)
	end

	local backpack, character = self:GetContainers(player)
	local snapshot = {}
	local usedSlots = {}
	local nextFreeSlot = 1

	local function claimNextFreeSlot(): number
		while usedSlots[nextFreeSlot] do
			nextFreeSlot += 1
		end
		local slot = nextFreeSlot
		usedSlots[slot] = true
		nextFreeSlot += 1
		return slot
	end

	for _, item in ipairs(self.ItemsByPlayer[player] or {}) do
		if item:IsOwnedBy(backpack, character) then
			if type(item.Slot) ~= 'number' or item.Slot < 1 or usedSlots[item.Slot] then
				item:SetSlot(claimNextFreeSlot())
			else
				usedSlots[item.Slot] = true
			end
			table.insert(snapshot, item:Serialize(character))
		end
	end

	table.sort(snapshot, function(a, b)
		return (a.Slot or math.huge) < (b.Slot or math.huge)
	end)

	return snapshot
end

function InventoryService:GetFirstFreeSlot(player: Player, startSlot: number, maxSlot: number?)
	local usedSlots = {}
	for _, item in ipairs(self.ItemsByPlayer[player] or {}) do
		if type(item.Slot) == 'number' and item.Slot >= 1 then
			usedSlots[item.Slot] = true
		end
	end

	local slot = math.max(1, math.floor(startSlot))
	while maxSlot == nil or slot <= maxSlot do
		if not usedSlots[slot] then
			return slot
		end
		slot += 1
	end

	return nil
end

function InventoryService:RefreshPlayer(player: Player, skipSync: boolean?)
	local snapshot = self:GetSnapshot(player, skipSync)
	Framework:GetController('InventoryController').Server.Fire.InventoryChanged(player, snapshot)
	return snapshot
end

function InventoryService:AddItem(player: Player, sourceModel: Model, itemType: string?, itemName: string?)
	local backpack = player:FindFirstChildOfClass('Backpack') or player:WaitForChild('Backpack', 5)
	if not backpack then
		warn(('[InventoryService] Missing Backpack for %s'):format(player.Name))
		return nil
	end

	local itemModel = sourceModel:Clone()
	local modelName = if type(itemName) == 'string' and itemName ~= '' then itemName else sourceModel.Name
	itemModel.Name = tostring(modelName)
	local resolvedItemType = itemType or self:GetItemType(itemModel)
	itemModel:SetAttribute(getInventoryConfig(self.Framework).ItemTypeAttribute or DEFAULT_ITEM_TYPE_ATTRIBUTE, resolvedItemType)
	prepInventoryModel(itemModel, false, resolvedItemType)
	if itemType == 'Brainrot' then
		BrainrotBillboard.Attach(itemModel, self.Framework, {
			Name = tostring(itemName or itemModel.Name),
			ModelName = itemModel.Name,
		})
	end
	itemModel.Parent = backpack

	return self:RefreshPlayer(player)
end

function InventoryService:MoveSlot(player: Player, fromSlot: number, toSlot: number)
	if self:IsInventoryLocked(player) then
		return self:GetSnapshot(player, true)
	end

	if type(fromSlot) ~= 'number' or type(toSlot) ~= 'number' then
		return self:GetSnapshot(player)
	end

	fromSlot = math.floor(fromSlot)
	toSlot = math.floor(toSlot)
	if fromSlot < 1 or toSlot < 1 or fromSlot == toSlot then
		return self:GetSnapshot(player)
	end

	local source = self:GetItemAtSlotNoSync(player, fromSlot)
	if not source then
		return self:GetSnapshot(player, true)
	end

	local target = self:GetItemAtSlotNoSync(player, toSlot)
	source:SetSlot(toSlot)
	if target then
		target:SetSlot(fromSlot)
	end

	sortItemsBySlot(self.ItemsByPlayer[player] or {})
	return self:RefreshPlayer(player, true)
end

function InventoryService:UnequipItemModel(player: Player, item, backpack: Backpack)
	clearEquipWeld(item.Model, getFirstBasePart(item.Model))
	prepInventoryModel(item.Model, false, item.ItemType)
	setModelNetworkOwner(item.Model, nil)
	if item.Model.Parent ~= backpack then
		item.Model.Parent = backpack
	end
end

function InventoryService:EquipItemModel(player: Player, item, backpack: Backpack, character: Model)
	if item:IsEquipped(character) then
		return self:GetSnapshot(player, true)
	end

	local previous = self:GetEquippedItemNoSync(player)
	if previous and previous ~= item then
		self:UnequipItemModel(player, previous, backpack)
	end

	local equipPart = if item.ItemType == 'Luckyblock' then getLuckyblockEquipPart(character) else getEquipPart(character)
	local itemPart = getFirstBasePart(item.Model)
	if not equipPart or not itemPart then
		return self:GetSnapshot(player, true)
	end

	prepInventoryModel(item.Model, true, item.ItemType)
	item.Model:PivotTo(getEquipPivot(equipPart, item.Model, item.ItemType, getInventoryConfig(self.Framework), character))
	weldModelToPart(item.Model, itemPart, equipPart)
	item.Model.Parent = character
	setModelNetworkOwner(item.Model, player)

	return self:RefreshPlayer(player, true)
end

function InventoryService:EquipSlot(player: Player, slot: number)
	if self:IsInventoryLocked(player) then
		return self:GetSnapshot(player, true)
	end

	if type(slot) ~= 'number' then
		return self:GetSnapshot(player)
	end

	return self:WithSuppressedRefresh(player, function()
		slot = math.floor(slot)
		local item = self:GetItemAtSlotNoSync(player, slot)
		local backpack, character = self:GetContainers(player)
		if not item or not backpack or not character or item:IsEquipped(character) then
			return self:GetSnapshot(player, true)
		end

		return self:EquipItemModel(player, item, backpack, character)
	end)
end

function InventoryService:UnequipItem(player: Player, suppressRefresh: boolean?)
	if self:IsInventoryLocked(player) then
		return self:GetSnapshot(player, true)
	end

	local backpack = player:FindFirstChildOfClass('Backpack')
	local item = self:GetEquippedItemNoSync(player)
	if not backpack or not item then
		return self:GetSnapshot(player, true)
	end

	local function unequip()
		self:UnequipItemModel(player, item, backpack)
		if suppressRefresh then
			return self:GetSnapshot(player, true)
		end
		return self:RefreshPlayer(player, true)
	end

	if suppressRefresh then
		return unequip()
	end

	return self:WithSuppressedRefresh(player, unequip)
end

function InventoryService:ToggleSlot(player: Player, slot: number)
	if self:IsInventoryLocked(player) then
		return self:GetSnapshot(player, true)
	end

	if type(slot) ~= 'number' then
		return self:GetSnapshot(player)
	end

	return self:WithSuppressedRefresh(player, function()
		local item = self:GetItemAtSlotNoSync(player, math.floor(slot))
		local backpack, character = self:GetContainers(player)
		if not item or not backpack or not character then
			return self:GetSnapshot(player, true)
		end
		if item:IsEquipped(character) then
			self:UnequipItemModel(player, item, backpack)
			return self:RefreshPlayer(player, true)
		end
		return self:EquipItemModel(player, item, backpack, character)
	end)
end

function InventoryService.Client:GetItems(player: Player)
	return self:GetSnapshot(player)
end

function InventoryService.Client:EquipSlot(player: Player, slot: number)
	return self:EquipSlot(player, slot)
end

function InventoryService.Client:UnequipItem(player: Player)
	return self:UnequipItem(player)
end

function InventoryService.Client:ToggleSlot(player: Player, slot: number)
	return self:ToggleSlot(player, slot)
end

function InventoryService.Client:MoveSlot(player: Player, fromSlot: number, toSlot: number)
	return self:MoveSlot(player, fromSlot, toSlot)
end

return InventoryService
