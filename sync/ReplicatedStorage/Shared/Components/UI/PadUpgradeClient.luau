local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local PadUpgradeClient = BaseComponent:Extend('PadUpgradeClient')

local function findTextLabel(root: Instance, name: string): TextLabel?
	local instance = root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextLabel') then instance else nil
end

local function findTextButton(root: Instance, name: string): TextButton?
	local instance = root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextButton') then instance else nil
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

function PadUpgradeClient:Create(upgradeModel: Model)
	self.Model = upgradeModel
	self.ButtonGui = findTextButton(upgradeModel, 'Button')
	self.PriceLabel = findTextLabel(upgradeModel, 'PriceTag')
	self.SlotsLabel = findTextLabel(upgradeModel, 'SlotsAmount')
	self.BaseService = self.Framework:GetService('BaseService')
	self.IsBuying = false

	if self.ButtonGui then
		self.Button = self.Framework.Components.Button:new(self.ButtonGui)
		self.Button:SetOnClick(function()
			self:Buy()
		end)
		self:AddChild(self.Button)
	end

	self:Refresh()
end

function PadUpgradeClient:Refresh()
	local ok, state = pcall(function()
		return self.BaseService:GetPadUpgradeState()
	end)
	if ok then
		self:ApplyState(state)
	else
		warn(('[PadUpgradeClient] GetPadUpgradeState failed: %s'):format(tostring(state)))
		self:ApplyState(nil)
	end
end

function PadUpgradeClient:ApplyState(state)
	if type(state) ~= 'table' or state.Ok ~= true then
		if self.ButtonGui then
			self.ButtonGui.Visible = false
			self.ButtonGui.Active = false
			pcall(function()
				(self.ButtonGui :: any).Interactable = false
			end)
		end
		return
	end

	if self.SlotsLabel then
		self.SlotsLabel.Text = if state.Maxed then '' else ('Slot #%d'):format(state.NextPadIndex or 0)
	end

	if self.PriceLabel then
		self.PriceLabel.Text = if state.Maxed or not state.NextPrice then '' else formatMoney(state.NextPrice)
	end

	if self.ButtonGui then
		local enabled = state.Maxed ~= true
		self.ButtonGui.Visible = enabled
		self.ButtonGui.Active = enabled and not self.IsBuying
		pcall(function()
			(self.ButtonGui :: any).Interactable = enabled and not self.IsBuying
		end)
	end
end

function PadUpgradeClient:Buy()
	if self.IsBuying then
		return
	end

	self.IsBuying = true
	if self.ButtonGui then
		self.ButtonGui.Active = false
		pcall(function()
			(self.ButtonGui :: any).Interactable = false
		end)
	end

	local ok, state = pcall(function()
		return self.BaseService:BuyNextPad()
	end)
	self.IsBuying = false

	if not rawget(self, '_alive') then
		return
	end

	if ok then
		self:ApplyState(state)
	else
		warn(('[PadUpgradeClient] BuyNextPad failed: %s'):format(tostring(state)))
		self:Refresh()
	end
end

return PadUpgradeClient
