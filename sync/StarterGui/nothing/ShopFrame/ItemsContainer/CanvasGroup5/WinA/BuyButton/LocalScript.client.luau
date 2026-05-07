--!strict

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local button = script.Parent

local DEV_PRODUCT_ID = 3534604652

if not button:IsA("GuiButton") then
	error("BuyButton must be a GuiButton")
end

button.Activated:Connect(function()
	MarketplaceService:PromptProductPurchase(player, DEV_PRODUCT_ID)
end)