--!strict

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local VIP_GAMEPASS_ID = 1711380423

local player = Players.LocalPlayer
local button = script.Parent

if not button:IsA("GuiButton") then
	error("BuyButton script must be parented to a GuiButton")
end

local function setOwned()
	if button:IsA("TextButton") then
		button.Text = "Owned"
	end
	button.Active = false
	button.AutoButtonColor = false
end

local function refresh()
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)

	if ok and owns then
		setOwned()
	end
end

button.Activated:Connect(function()
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)

	if ok and owns then
		setOwned()
		return
	end

	MarketplaceService:PromptGamePassPurchase(player, VIP_GAMEPASS_ID)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, gamePassId: number, wasPurchased: boolean)
	if plr ~= player then
		return
	end
	if gamePassId ~= VIP_GAMEPASS_ID then
		return
	end
	if not wasPurchased then
		return
	end

	setOwned()
end)

refresh()