--!strict

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = script.Parent
local leftBarRoot = root

local function waitChild(parent: Instance, name: string, timeout: number): Instance?
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local inst = parent:FindFirstChild(name)
		if inst then
			return inst
		end
		task.wait(0.05)
	end
	return nil
end

local function findButton(name: string): GuiButton?
	local inst = leftBarRoot:FindFirstChild(name, true)
	if inst and inst:IsA("GuiButton") then
		return inst
	end
	return nil
end

local purplesAny = waitChild(playerGui, "PurplesUI", 10)
if not purplesAny or not purplesAny:IsA("ScreenGui") then
	return
end
local purplesUI = purplesAny :: ScreenGui

local function findFrame(name: string): Frame?
	local inst = purplesUI:FindFirstChild(name, true)
	if inst and inst:IsA("Frame") then
		return inst
	end
	return nil
end

local shopFrame = findFrame("ShopFrame")
local codesFrame = findFrame("CodesFrame")
local invFrame = findFrame("InventoryFrame")
local rewardsFrame = findFrame("RewardsFrame")

local function hideAll()
	if shopFrame then shopFrame.Visible = false end
	if codesFrame then codesFrame.Visible = false end
	if invFrame then invFrame.Visible = false end
	if rewardsFrame then rewardsFrame.Visible = false end
	purplesUI.Enabled = false
end

local function showOnly(target: Frame)
	if shopFrame then shopFrame.Visible = false end
	if codesFrame then codesFrame.Visible = false end
	if invFrame then invFrame.Visible = false end
	if rewardsFrame then rewardsFrame.Visible = false end
	purplesUI.Enabled = true
	target.Visible = true
end

local function hook(btn: GuiButton?, frame: Frame?)
	if not (btn and frame) then
		return
	end
	btn.Activated:Connect(function()
		if purplesUI.Enabled and frame.Visible then
			hideAll()
		else
			showOnly(frame)
		end
	end)
end

hook(findButton("ShopButton"), shopFrame)
hook(findButton("StoreButton"), shopFrame)
hook(findButton("CodesButton"), codesFrame)
hook(findButton("InventoryButton"), invFrame)
hook(findButton("RewardsButton"), rewardsFrame)

local function hookClose(frame: Frame?)
	if not frame then
		return
	end
	local closeBtn = frame:FindFirstChild("CloseButton", true)
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.Activated:Connect(function()
			hideAll()
		end)
	end
end

hookClose(shopFrame)
hookClose(codesFrame)
hookClose(invFrame)
hookClose(rewardsFrame)

hideAll()