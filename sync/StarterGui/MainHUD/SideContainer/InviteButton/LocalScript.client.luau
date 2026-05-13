--!strict

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer
local button = script.Parent :: GuiButton

local function promptInvite()
	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end

button.Activated:Connect(promptInvite)