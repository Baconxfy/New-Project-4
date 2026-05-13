local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local InventorySlotClient = BaseComponent:Extend('InventorySlotClient')

local SLOT_BG = Color3.fromRGB(42, 43, 48)
local SLOT_BG_HOVER = Color3.fromRGB(54, 55, 62)
local SLOT_BG_EQUIPPED = Color3.fromRGB(70, 86, 122)
local SLOT_STROKE = Color3.fromRGB(24, 25, 28)
local SLOT_STROKE_ACTIVE = Color3.fromRGB(255, 255, 255)
local TEXT = Color3.fromRGB(245, 245, 245)
local TEXT_MUTED = Color3.fromRGB(190, 193, 199)
local DRAG_THRESHOLD = 8

local function findLabel(root: Instance, name: string): TextLabel?
	local child = root:FindFirstChild(name, true)
	return if child and child:IsA('TextLabel') then child else nil
end

local function getItemType(item): string
	return (item and item.ItemType) or ''
end

function InventorySlotClient:Create(template: ImageButton, parent: Instance, name: string, onActivated: (number) -> (), onDragEnded: ((number, Vector2) -> ())?)
	self.Button = template:Clone()
	self.Button.Name = name
	self.Button.Visible = true
	self.Button.Parent = parent
	self.OnActivated = onActivated
	self.OnDragEnded = onDragEnded
	self.Item = nil
	self.Slot = nil
	self.IsSelected = false
	self.IsEquipped = false
	self.IsHovered = false
	self.IsDragging = false
	self.DragStart = nil

	self.AmountLabel = findLabel(self.Button, 'AmountLabel')
	self.SlotNumberLabel = findLabel(self.Button, 'SlotNumber')
	self.Stroke = self.Button:FindFirstChildOfClass('UIStroke')
	self.Icon = self.Button:FindFirstChild('ImageLabel', true)

	self:Style()

	self:AddConnection(self.Button.Activated:Connect(function()
		if self.Slot and self.Item and not self.IsDragging then
			self.OnActivated(self.Slot)
		end
	end))
	self:AddConnection(self.Button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.DragStart = input.Position
			self.IsDragging = false
		end
	end))
	self:AddConnection(UserInputService.InputChanged:Connect(function(input)
		if not self.DragStart or not self.Item then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - self.DragStart
		if math.abs(delta.X) >= DRAG_THRESHOLD or math.abs(delta.Y) >= DRAG_THRESHOLD then
			self.IsDragging = true
		end
	end))
	self:AddConnection(UserInputService.InputEnded:Connect(function(input)
		if not self.DragStart then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local wasDragging = self.IsDragging
		local slot = self.Slot
		self.DragStart = nil
		task.defer(function()
			self.IsDragging = false
		end)

		if wasDragging and slot and self.Item and self.OnDragEnded then
			self.OnDragEnded(slot, Vector2.new(input.Position.X, input.Position.Y))
		end
	end))
	self:AddConnection(self.Button.MouseEnter:Connect(function()
		self.IsHovered = true
		self:ApplyState()
	end))
	self:AddConnection(self.Button.MouseLeave:Connect(function()
		self.IsHovered = false
		self:ApplyState()
	end))
end

function InventorySlotClient:Style()
	self.Button.AutoButtonColor = false
	self.Button.BackgroundTransparency = 0.08
	self.Button.BorderSizePixel = 0
	self.Button.Image = ''

	if self.Icon and self.Icon:IsA('ImageLabel') then
		self.Icon.BackgroundTransparency = 1
		self.Icon.ImageTransparency = 1
	end

	if self.AmountLabel then
		self.AmountLabel.TextColor3 = TEXT_MUTED
		self.AmountLabel.TextScaled = true
		self.AmountLabel.BackgroundTransparency = 1
	end

	if self.SlotNumberLabel then
		self.SlotNumberLabel.TextColor3 = TEXT
		self.SlotNumberLabel.TextScaled = true
		self.SlotNumberLabel.BackgroundTransparency = 1
	end

	if self.Stroke then
		self.Stroke.Color = SLOT_STROKE
		self.Stroke.Thickness = 1
		self.Stroke.Transparency = 0.15
	end
end

function InventorySlotClient:SetSlotNumber(text: string?)
	if self.SlotNumberLabel then
		self.SlotNumberLabel.Text = text or ''
	end
end

function InventorySlotClient:SetLayoutOrder(layoutOrder: number)
	self.Button.LayoutOrder = layoutOrder
end

function InventorySlotClient:SetItem(item, selectedSlot: number?, equippedSlot: number?)
	self.Item = item
	self.Slot = item and item.Slot or nil
	self.Button.Visible = item ~= nil
	self.IsSelected = self.Slot ~= nil and selectedSlot == self.Slot
	self.IsEquipped = self.Slot ~= nil and equippedSlot == self.Slot

	if self.AmountLabel then
		self.AmountLabel.Text = if item then getItemType(item) else ''
	end

	self:ApplyState()
end

function InventorySlotClient:SetEmptySlot(slot: number, selectedSlot: number?, equippedSlot: number?)
	self.Item = nil
	self.Slot = slot
	self.Button.Visible = false
	self.IsSelected = selectedSlot == slot
	self.IsEquipped = equippedSlot == slot

	if self.AmountLabel then
		self.AmountLabel.Text = ''
	end

	self:ApplyState()
end

function InventorySlotClient:ApplyState()
	if self.IsEquipped then
		self.Button.BackgroundColor3 = SLOT_BG_EQUIPPED
	elseif self.IsHovered and self.Item then
		self.Button.BackgroundColor3 = SLOT_BG_HOVER
	else
		self.Button.BackgroundColor3 = SLOT_BG
	end

	if self.Stroke then
		self.Stroke.Color = if self.IsEquipped then SLOT_STROKE_ACTIVE else SLOT_STROKE
		self.Stroke.Thickness = if self.IsEquipped then 2 else 1
		self.Stroke.Transparency = if self.IsEquipped then 0 else 1
	end
end

function InventorySlotClient:CleanUp()
	if self.Button and self.Button.Parent then
		self.Button:Destroy()
	end
end

return InventorySlotClient
