local ReplicatedStorage = game:GetService('ReplicatedStorage')
local StarterGui = game:GetService('StarterGui')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local InventoryGuiClient = BaseComponent:Extend('InventoryGuiClient')

local HOTBAR_SIZE = 10
local TAB_ALL = 'All'
local TAB_BRAINROTS = 'Brainrot'
local TAB_LUCKYBLOCKS = 'Luckyblock'

local TEXT = Color3.fromRGB(245, 245, 245)
local TEXT_MUTED = Color3.fromRGB(190, 193, 199)
local PANEL = Color3.fromRGB(31, 32, 36)
local TAB_BG = Color3.fromRGB(48, 49, 55)
local TAB_BG_ACTIVE = Color3.fromRGB(75, 77, 86)
local STROKE = Color3.fromRGB(24, 25, 28)
local STROKE_ACTIVE = Color3.fromRGB(255, 255, 255)

local function getItemType(item): string
	return (item and item.ItemType) or ''
end

local function getItemName(item): string
	local model = item and item.Model
	if model then
		return model.Name
	end
	if type(item and item.ModelName) == 'string' then
		return item.ModelName
	end
	return ''
end

local function getDisplayName(item): string
	local name = getItemName(item)
	if name ~= '' then
		return name
	end
	return getItemType(item)
end

local function getTextButton(parent: Instance, name: string): TextButton?
	local child = parent:FindFirstChild(name, true)
	return if child and child:IsA('TextButton') then child else nil
end

local function getTextBox(parent: Instance, name: string): TextBox?
	local child = parent:FindFirstChild(name, true)
	return if child and child:IsA('TextBox') then child else nil
end

local function itemsBySlot(items)
	local bySlot = {}
	for _, item in ipairs(items) do
		bySlot[item.Slot] = item
	end
	return bySlot
end

local function containsPoint(guiObject: GuiObject, point: Vector2): boolean
	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= position.X
		and point.Y >= position.Y
		and point.X <= position.X + size.X
		and point.Y <= position.Y + size.Y
end

function InventoryGuiClient:Create(gui: ScreenGui, inventoryController)
	self.Gui = gui
	self.InventoryController = inventoryController
	self.InventoryFrame = gui:WaitForChild('InventoryFrame')
	self.HotbarFrame = gui:WaitForChild('HotbarFrame')
	self.ItemsHolder = self.InventoryFrame:WaitForChild('ItemsHolder')
	self.InventoryTemplate = self.ItemsHolder:WaitForChild('ItemSlotTemplate')
	self.HotbarTemplate = self.HotbarFrame:WaitForChild('ItemSlotTemplate')
	self.SearchBox = getTextBox(self.InventoryFrame, 'SearchButton')
	self.TabButtons = {
		[TAB_ALL] = getTextButton(self.InventoryFrame, 'AllItemsButton'),
		[TAB_BRAINROTS] = getTextButton(self.InventoryFrame, 'BrainrotsButton'),
		[TAB_LUCKYBLOCKS] = getTextButton(self.InventoryFrame, 'LuckyBlocksButton'),
	}

	assert(self.InventoryFrame:IsA('Frame'), '[InventoryGuiClient] Missing InventoryFrame')
	assert(self.HotbarFrame:IsA('Frame'), '[InventoryGuiClient] Missing HotbarFrame')
	assert(self.ItemsHolder:IsA('ScrollingFrame'), '[InventoryGuiClient] Missing ItemsHolder')
	assert(self.InventoryTemplate:IsA('ImageButton'), '[InventoryGuiClient] Missing inventory ItemSlotTemplate')
	assert(self.HotbarTemplate:IsA('ImageButton'), '[InventoryGuiClient] Missing hotbar ItemSlotTemplate')

	self.CurrentItems = {}
	self.SelectedSlot = nil
	self.EquippedSlot = nil
	self.ActiveTab = TAB_ALL
	self.SearchText = ''
	self.IsBackpackOpen = false
	self.HotbarSlots = {}
	self.InventorySlots = {}

	self:StyleStaticGui()
	self:SetDefaultBackpackEnabled(false)
	self:BindTabs()
	self:BindSearch()

	self:AddConnection(inventoryController.Changed.Event:Connect(function(items, selectedSlot, equippedSlot)
		self:ApplySnapshot(items, selectedSlot, equippedSlot)
	end))
	self:AddConnection(inventoryController.BackpackToggleRequested.Event:Connect(function()
		self:SetBackpackOpen(not self.IsBackpackOpen)
	end))

	self:ApplySnapshot(inventoryController:GetItems(), inventoryController.SelectedSlot, inventoryController.EquippedSlot)
end

function InventoryGuiClient:SetDefaultBackpackEnabled(enabled: boolean)
	for _ = 1, 5 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
		end)
		if ok then
			return
		end
		task.wait()
	end
end

function InventoryGuiClient:StyleStaticGui()
	self.Gui.Enabled = true
	self.Gui.ResetOnSpawn = false
	self.InventoryFrame.Visible = false
	self.HotbarFrame.Visible = true
	self.InventoryFrame.BackgroundColor3 = PANEL
	self.InventoryFrame.BackgroundTransparency = 0.08
	self.HotbarFrame.BackgroundTransparency = 1
	self.InventoryTemplate.Visible = false
	self.HotbarTemplate.Visible = false

	if self.SearchBox then
		self.SearchBox.PlaceholderText = 'Search'
		self.SearchBox.Text = ''
		self.SearchBox.ClearTextOnFocus = false
		self.SearchBox.BackgroundColor3 = Color3.fromRGB(42, 43, 48)
		self.SearchBox.TextColor3 = TEXT
		self.SearchBox.PlaceholderColor3 = TEXT_MUTED
	end
end

function InventoryGuiClient:BindTabs()
	for tabName, button in pairs(self.TabButtons) do
		if button then
			self:AddConnection(button.Activated:Connect(function()
				self.ActiveTab = tabName
				self:RenderTabs()
				self:RenderInventory()
			end))
		end
	end
	self:RenderTabs()
end

function InventoryGuiClient:BindSearch()
	if not self.SearchBox then
		return
	end

	self:AddConnection(self.SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
		self.SearchText = self.SearchBox.Text:lower()
		self:RenderInventory()
	end))
end

function InventoryGuiClient:RenderTabs()
	for tabName, button in pairs(self.TabButtons) do
		if button then
			local active = self.ActiveTab == tabName
			button.BackgroundColor3 = if active then TAB_BG_ACTIVE else TAB_BG
			button.TextColor3 = TEXT
			button.AutoButtonColor = true

			local stroke = button:FindFirstChildOfClass('UIStroke')
			if stroke then
				stroke.Color = if active then STROKE_ACTIVE else STROKE
				stroke.Thickness = if active then 2 else 1
			end
		end
	end
end

function InventoryGuiClient:ApplySnapshot(items, selectedSlot, equippedSlot)
	self.CurrentItems = items or {}
	self.SelectedSlot = selectedSlot
	self.EquippedSlot = equippedSlot
	self:RenderHotbar()
	if self.IsBackpackOpen then
		self:RenderInventory()
	end
end

function InventoryGuiClient:RenderHotbar()
	local bySlot = itemsBySlot(self.CurrentItems)
	for slot = 1, HOTBAR_SIZE do
		local item = bySlot[slot]
		local component = self.HotbarSlots[slot]
		if not component then
			component = self.Framework.Components.InventorySlotClient:new(
				self.HotbarTemplate,
				self.HotbarFrame,
				('Slot%d'):format(slot),
				function(slotNumber)
					self:ActivateSlot(slotNumber)
				end,
				function(slotNumber, screenPosition)
					self:MoveSlotFromDrag(slotNumber, screenPosition)
				end
			)
			component:SetLayoutOrder(slot)
			component:SetSlotNumber(if slot == 10 then '0' else tostring(slot))
			self.HotbarSlots[slot] = component
		end

		if item then
			component:SetItem(item, self.SelectedSlot, self.EquippedSlot)
		else
			component:SetEmptySlot(slot, self.SelectedSlot, self.EquippedSlot)
		end
	end
end

function InventoryGuiClient:RenderInventory()
	local seen = {}

	for _, item in ipairs(self.CurrentItems) do
		if item.Slot > HOTBAR_SIZE and self:ShouldShowItem(item) then
			seen[item.Slot] = true
			local component = self.InventorySlots[item.Slot]
			if not component then
				component = self.Framework.Components.InventorySlotClient:new(
					self.InventoryTemplate,
					self.ItemsHolder,
					('InventorySlot%d'):format(item.Slot),
					function(slotNumber)
						self:ActivateSlot(slotNumber)
					end,
					function(slotNumber, screenPosition)
						self:MoveSlotFromDrag(slotNumber, screenPosition)
					end
				)
				self.InventorySlots[item.Slot] = component
			end
			component:SetLayoutOrder(item.Slot)
			component:SetItem(item, self.SelectedSlot, self.EquippedSlot)
		end
	end

	for slot, component in pairs(self.InventorySlots) do
		if not seen[slot] then
			component:Destroy()
			self.InventorySlots[slot] = nil
		end
	end

	task.defer(function()
		if self._alive then
			self:UpdateCanvas()
		end
	end)
end

function InventoryGuiClient:ShouldShowItem(item): boolean
	if self.ActiveTab ~= TAB_ALL and getItemType(item) ~= self.ActiveTab then
		return false
	end

	if self.SearchText == '' then
		return true
	end

	local haystack = (getDisplayName(item) .. ' ' .. getItemType(item)):lower()
	return haystack:find(self.SearchText, 1, true) ~= nil
end

function InventoryGuiClient:UpdateCanvas()
	local layout = self.ItemsHolder:FindFirstChildOfClass('UIGridLayout')
	if layout then
		self.ItemsHolder.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
	end
end

function InventoryGuiClient:SetBackpackOpen(isOpen: boolean)
	self.IsBackpackOpen = isOpen
	self.InventoryFrame.Visible = isOpen

	if isOpen then
		self:RenderInventory()
	else
		self:ClearInventorySlots()
	end
end

function InventoryGuiClient:GetFirstFreeHotbarSlot(): number?
	local usedSlots = {}
	for _, item in ipairs(self.CurrentItems) do
		if item.Slot <= HOTBAR_SIZE then
			usedSlots[item.Slot] = true
		end
	end

	for slot = 1, HOTBAR_SIZE do
		if not usedSlots[slot] then
			return slot
		end
	end

	return nil
end

function InventoryGuiClient:GetFirstFreeInventorySlot(): number
	local usedSlots = {}
	local maxSlot = HOTBAR_SIZE
	for _, item in ipairs(self.CurrentItems) do
		usedSlots[item.Slot] = true
		maxSlot = math.max(maxSlot, item.Slot)
	end

	local slot = HOTBAR_SIZE + 1
	while usedSlots[slot] do
		slot += 1
	end

	return slot
end

function InventoryGuiClient:GetDropSlot(screenPosition: Vector2, fromSlot: number): number?
	for slot, component in pairs(self.HotbarSlots) do
		if component.Button.Visible and containsPoint(component.Button, screenPosition) then
			return slot
		end
	end

	for _, component in pairs(self.InventorySlots) do
		if component.Button.Visible and containsPoint(component.Button, screenPosition) then
			return component.Slot
		end
	end

	if containsPoint(self.HotbarFrame, screenPosition) then
		return self:GetFirstFreeHotbarSlot()
	end

	if self.IsBackpackOpen and containsPoint(self.InventoryFrame, screenPosition) then
		return self:GetFirstFreeInventorySlot()
	end

	return fromSlot
end

function InventoryGuiClient:MoveSlotFromDrag(fromSlot: number, screenPosition: Vector2)
	local toSlot = self:GetDropSlot(screenPosition, fromSlot)
	if not toSlot or toSlot == fromSlot then
		return
	end

	self.InventoryController:MoveSlot(fromSlot, toSlot)
end

function InventoryGuiClient:ActivateSlot(slot: number)
	if not self.InventoryController:GetSlotItem(slot) then
		return
	end

	self.InventoryController:ToggleSlot(slot)
end

function InventoryGuiClient:ClearInventorySlots()
	for _, component in pairs(self.InventorySlots) do
		component:Destroy()
	end
	table.clear(self.InventorySlots)
end

function InventoryGuiClient:ClearHotbarSlots()
	for _, component in pairs(self.HotbarSlots) do
		component:Destroy()
	end
	table.clear(self.HotbarSlots)
end

function InventoryGuiClient:CleanUp()
	self:ClearHotbarSlots()
	self:ClearInventorySlots()
	self:SetDefaultBackpackEnabled(true)
end

return InventoryGuiClient
