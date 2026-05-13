local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = Framework:CreateService("DataService")
local Packages = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages")
local Signal = require(Packages:WaitForChild("Signal") :: ModuleScript)
local ProfileStore = require(Packages:WaitForChild("ProfileStore") :: ModuleScript)

local DEFAULT_DATA_VERSION = "BrainrotTycoon-v1"
local DEFAULT_STUDIO_SUFFIX = "-studio"

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

function DataService:Initialize()
	self.Profiles = {}
	self.StatChanged = Signal.new()
	self.ProfileLoaded = Signal.new()
	self.ProfileStore = ProfileStore

	local dataVersion = Framework.Config.DataVersion or DEFAULT_DATA_VERSION
	if RunService:IsStudio() then
		dataVersion = Framework.Config.DataVersionStudio or (dataVersion .. DEFAULT_STUDIO_SUFFIX)
	end

	self.PlayerStore = self.ProfileStore.New(dataVersion, Framework.Config.ProfileTemplate or {})
end

function DataService:Start()
	task.spawn(function()
		while self.ProfileStore.DataStoreState == "NotReady" do
			task.wait()
		end

		if self.ProfileStore.DataStoreState ~= "Access" then
			warn(("[DataService] ProfileStore is in %s mode. Studio data will not persist unless the experience is published and Studio API access is enabled."):format(self.ProfileStore.DataStoreState))
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:PlayerAdded(player)
		end)
	end

	self:AddConnection(Players.PlayerAdded:Connect(function(player)
		self:PlayerAdded(player)
	end))

	self:AddConnection(Players.PlayerRemoving:Connect(function(player)
		self:PlayerRemoving(player)
	end))
end

function DataService:CreateLeaderstats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	for _, category in ipairs(Framework.Config.LeaderstatsCategories or {}) do
		local template = (Framework.Config.ProfileTemplate or {})[category]
		if typeof(template) == "number" then
			local stat = leaderstats:FindFirstChild(category) or Instance.new("IntValue")
			stat.Name = category
			stat.Value = template
			stat.Parent = leaderstats
		elseif typeof(template) == "string" then
			local stat = leaderstats:FindFirstChild(category) or Instance.new("StringValue")
			stat.Name = category
			stat.Value = template
			stat.Parent = leaderstats
		end
	end
end

function DataService:ApplyProfileToLeaderstats(player: Player)
	local profile = self.Profiles[player.UserId]
	if not profile then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	for _, category in ipairs(Framework.Config.LeaderstatsCategories or {}) do
		local stat = leaderstats:FindFirstChild(category)
		local value = profile.Data[category]
		if stat and value ~= nil and typeof(value) == typeof(stat.Value) then
			stat.Value = value
		end
	end
end

function DataService:PlayerAdded(player: Player)
	self:CreateLeaderstats(player)
	self:LoadData(player)
	self:ApplyProfileToLeaderstats(player)
end

function DataService:PlayerRemoving(player: Player)
	local profile = self.Profiles[player.UserId]
	if not profile then
		return
	end

	self.Profiles[player.UserId] = nil
	profile:EndSession()
end

function DataService:CloseProfiles()
	for userId, profile in pairs(self.Profiles) do
		self.Profiles[userId] = nil
		profile:EndSession()
	end
end

function DataService:LoadData(player: Player)
	local profile = self.PlayerStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	self.Profiles[player.UserId] = profile
	self.ProfileLoaded:Fire(player.UserId, profile, player)

	profile.OnSessionEnd:Connect(function()
		self.Profiles[player.UserId] = nil
		if player.Parent == Players then
			player:Kick("Data session ended. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		self.Profiles[player.UserId] = nil
		profile:EndSession()
	end
end

function DataService:GetProfile(userId: number)
	return self.Profiles[userId]
end

function DataService:GetData(userId: number, category: string)
	local profile = self.Profiles[userId]
	if not profile then
		return nil
	end
	return profile.Data[category]
end

function DataService:UpdatePlayerData(userId: number, category: string, newValue)
	local profile = self:GetProfileAsync(userId)
	if not profile then
		return false
	end

	local oldValue = profile.Data[category]
	if oldValue ~= nil and typeof(oldValue) ~= typeof(newValue) then
		warn(("[DataService] Conflicting types writing to category %s"):format(category))
		return false
	end

	profile.Data[category] = deepCopy(newValue)
	self:UpdateLeaderstat(userId, category, newValue)
	self:SaveProfile(profile)

	local delta = 0
	if typeof(oldValue) == "number" and typeof(newValue) == "number" then
		delta = newValue - oldValue
	end
	self.StatChanged:Fire(userId, category, newValue, delta)
	return true
end

function DataService:AddPlayerData(userId: number, category: string, addValue: number)
	if typeof(addValue) ~= "number" then
		return false
	end

	local profile = self:GetProfileAsync(userId)
	if not profile or typeof(profile.Data[category]) ~= "number" then
		return false
	end

	local newValue = profile.Data[category] + addValue
	profile.Data[category] = newValue
	self:UpdateLeaderstat(userId, category, newValue)
	self:SaveProfile(profile)
	self.StatChanged:Fire(userId, category, newValue, addValue)
	return true
end

function DataService:GetProfileAsync(userId: number, timeout: number?)
	local profile = self.Profiles[userId]
	if profile then
		return profile
	end

	local startedAt = os.clock()
	local maxWait = timeout or 10
	while os.clock() - startedAt < maxWait do
		profile = self.Profiles[userId]
		if profile then
			return profile
		end
		task.wait()
	end

	return nil
end

function DataService:SaveProfile(profile)
	if not profile or type(profile.Save) ~= "function" then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			profile:Save()
		end)
		if not ok then
			warn("[DataService] Profile save failed:", err)
		end
	end)
end

function DataService:UpdateLeaderstat(userId: number, category: string, value)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(category)
	if stat and typeof(stat.Value) == typeof(value) then
		stat.Value = value
	end
end

function DataService.Client:GetData(player: Player, category: string)
	return self:GetData(player.UserId, category)
end

return DataService
