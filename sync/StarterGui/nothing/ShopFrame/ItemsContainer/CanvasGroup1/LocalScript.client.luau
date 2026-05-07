--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local row = script.Parent :: CanvasGroup

local GAMEPASS_ID = 1727935959

local destroyed = false

local function destroyStarterPackUI()
	if destroyed then
		return
	end
	destroyed = true

	local gui = row:FindFirstAncestorWhichIsA("ScreenGui")
	if gui then
		local sb = gui:FindFirstChild("StarterpackButton", true)
		if sb and sb:IsA("GuiObject") then
			sb:Destroy()
		end
	end

	if row and row.Parent then
		row:Destroy()
	end
end

local function ownsPass(): boolean
	local ok, res = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
	end)
	return ok and res == true
end

task.defer(function()
	if ownsPass() then
		destroyStarterPackUI()
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, passId: number, purchased: boolean)
	if plr ~= player then
		return
	end
	if passId ~= GAMEPASS_ID then
		return
	end
	if purchased then
		destroyStarterPackUI()
	end
end)