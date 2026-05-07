local Framework: any = require(game:GetService('ReplicatedStorage').Framework :: ModuleScript)

local Players = game:GetService('Players')

local InventoryService = Framework:CreateService('InventoryService')

local EQUIP_WELD_NAME = 'InventoryEquipWeld'
local EQUIP_OFFSET = CFrame.new(0, -0.75, -1) * CFrame.Angles(0, math.rad(90), 0)

local function getFirstBasePart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BasePart') then
			model.PrimaryPart = descendant
			return descendant
		end
	end
	return nil
end

local function getEquipPart(character: Model): BasePart?
	return character:FindFirstChild('RightHand') :: BasePart?
		or character:FindFirstChild('Right Arm') :: BasePart?
		or character:FindFirstChild('HumanoidRootPart') :: BasePart?
end

local function clearEquipWeld(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('WeldConstraint') and descendant.Name == EQUIP_WELD_NAME then
			descendant:Destroy()
		end
	end
end

local function prepInventoryModel(model: Model, equipped: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BasePart') then
			descendant.Anchored = not equipped
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = equipped
		end
	end
end

function InventoryService:Initialize()
	self.ItemsByPlayer = {}
	self.ConnectionsByPlayer = {}
	self.CharacterConnectionsByPlayer = {}
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
	self.ConnectionsByPlayer[player] = {}
	local backpack = player:WaitForChild('Backpack')

	table.insert(self.ConnectionsByPlayer[player], backpack.ChildAdded:Connect(function(child)
		if self:GetItemFromModel(player, child) then
			prepInventoryModel(child :: Model, false)
			self:RefreshPlayer(player)
		end
	end))

	table.insert(self.ConnectionsByPlayer[player], backpack.ChildRemoved:Connect(function(child)
		if self:GetItemFromModel(player, child) then
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
		if self:GetItemFromModel(player, child) then
			self:RefreshPlayer(player)
		end
	end))

	table.insert(connections, character.ChildRemoved:Connect(function(child)
		if self:GetItemFromModel(player, child) then
			self:RefreshPlayer(player)
		end
	end))
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
	self.ConnectionsByPlayer[player] = nil
	self.CharacterConnectionsByPlayer[player] = nil
end

function InventoryService:GetContainers(player: Player)
	return player:FindFirstChildOfClass('Backpack'), player.Character
end

function InventoryService:GetItemFromModel(player: Player, model: Instance)
	if not model:IsA('Model') then
		return nil
	end

	for _, item in ipairs(self.ItemsByPlayer[player] or {}) do
		if item.Model == model then
			return item
		end
	end
	return nil
end

function InventoryService:GetItemAtSlot(player: Player, slot: number)
	local item = self.ItemsByPlayer[player] and self.ItemsByPlayer[player][slot]
	if not item then
		return nil
	end

	local backpack, character = self:GetContainers(player)
	if item:IsOwnedBy(backpack, character) then
		return item
	end
	return nil
end

function InventoryService:GetEquippedItem(player: Player)
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

function InventoryService:TakeEquippedLuckyblock(player: Player)
	local item = self:GetEquippedItem(player)
	if not item or item.ItemType ~= 'Luckyblock' then
		return nil
	end

	local items = self.ItemsByPlayer[player]
	local index = items and table.find(items, item)
	if not items or not index then
		return nil
	end

	local model = item.Model
	local luckyblockName = item.Name
	clearEquipWeld(model)
	prepInventoryModel(model, false)
	table.remove(items, index)
	item:Destroy()
	self:RefreshPlayer(player)

	return model, luckyblockName
end

function InventoryService:GetSnapshot(player: Player)
	local backpack, character = self:GetContainers(player)
	local snapshot = {}

	for slot, item in ipairs(self.ItemsByPlayer[player] or {}) do
		item:SetSlot(slot)
		if item:IsOwnedBy(backpack, character) then
			table.insert(snapshot, item:Serialize(character))
		end
	end

	return snapshot
end

function InventoryService:RefreshPlayer(player: Player)
	local snapshot = self:GetSnapshot(player)
	Framework:GetController('InventoryController').Server.Fire.InventoryChanged(player, snapshot)
	return snapshot
end

function InventoryService:AddLuckyblock(player: Player, sourceModel: Model, luckyblockName: string)
	local backpack = player:FindFirstChildOfClass('Backpack') or player:WaitForChild('Backpack', 5)
	if not backpack then
		warn(('[InventoryService] Missing Backpack for %s'):format(player.Name))
		return nil
	end

	local itemModel = sourceModel:Clone()
	itemModel.Name = luckyblockName
	prepInventoryModel(itemModel, false)
	itemModel.Parent = backpack

	local item = Framework.Components.InventoryItemServer:new(itemModel, 'Luckyblock')
	local items = self.ItemsByPlayer[player]
	if not items then
		items = {}
		self.ItemsByPlayer[player] = items
	end
	table.insert(items, item)
	item:SetSlot(#items)

	self:RefreshPlayer(player)
	return item:Serialize(player.Character)
end

function InventoryService:EquipSlot(player: Player, slot: number)
	if type(slot) ~= 'number' then
		return self:GetSnapshot(player)
	end

	slot = math.floor(slot)
	local item = self:GetItemAtSlot(player, slot)
	local backpack, character = self:GetContainers(player)
	if not item or not backpack or not character or item.Model.Parent == character then
		return self:GetSnapshot(player)
	end

	local previous = self:GetEquippedItem(player)
	if previous then
		self:UnequipItem(player)
	end

	local equipPart = getEquipPart(character)
	local itemPart = getFirstBasePart(item.Model)
	if not equipPart or not itemPart then
		return self:GetSnapshot(player)
	end

	clearEquipWeld(item.Model)
	prepInventoryModel(item.Model, true)
	item.Model.Parent = character
	item.Model:PivotTo(equipPart.CFrame * EQUIP_OFFSET)

	local weld = Instance.new('WeldConstraint')
	weld.Name = EQUIP_WELD_NAME
	weld.Part0 = equipPart
	weld.Part1 = itemPart
	weld.Parent = itemPart

	return self:RefreshPlayer(player)
end

function InventoryService:UnequipItem(player: Player)
	local backpack = player:FindFirstChildOfClass('Backpack')
	local item = self:GetEquippedItem(player)
	if not backpack or not item then
		return self:GetSnapshot(player)
	end

	clearEquipWeld(item.Model)
	prepInventoryModel(item.Model, false)
	item.Model.Parent = backpack
	return self:RefreshPlayer(player)
end

function InventoryService:ToggleSlot(player: Player, slot: number)
	if type(slot) ~= 'number' then
		return self:GetSnapshot(player)
	end

	local item = self:GetItemAtSlot(player, math.floor(slot))
	local _, character = self:GetContainers(player)
	if not item then
		return self:GetSnapshot(player)
	end
	return if item:IsEquipped(character) then self:UnequipItem(player) else self:EquipSlot(player, slot)
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

return InventoryService
