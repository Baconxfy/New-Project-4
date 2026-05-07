local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local PlayerUtil = {}

local ICON_VERIFIED = utf8.char(0xE000)
local ICON_PREMIUM = utf8.char(0xE001)
local ICON_ROBUX = utf8.char(0xE002)

export type BadgeState = {
	premium: boolean,
	verified: boolean,
}

type CachedUser = {
	username: string?,
	displayName: string?,
	premium: boolean?,
	verified: boolean?,
	_userServiceFetched: boolean?,
}

export type FormatOptions = {
	-- Base name selection
	useDisplayName: boolean?, -- default false -> Username, true -> DisplayName
	includeAt: boolean?, -- default true (e.g. @Username)

	-- Show badges?
	showPremium: boolean?, -- default true
	showVerified: boolean?, -- default true

	-- Badge placement
	badgesBeforeName: boolean?, -- default false

	-- Custom icons (defaults are Roblox unicode icons)
	premiumIcon: string?, -- default ICON_PREMIUM
	verifiedIcon: string?, -- default ICON_VERIFIED

	-- Spacing
	separator: string?, -- default " "
}

local DEFAULTS: FormatOptions = {
	useDisplayName = false,
	includeAt = true,

	showPremium = true,
	showVerified = true,

	badgesBeforeName = true,

	premiumIcon = ICON_PREMIUM,
	verifiedIcon = ICON_VERIFIED,

	separator = "",
}

local userCache: { [number]: CachedUser } = {}

local function mergeOptions(opts: FormatOptions?): FormatOptions
	if not opts then
		return DEFAULTS
	end

	local merged: any = {}
	for k, v in pairs(DEFAULTS :: any) do
		merged[k] = v
	end
	for k, v in pairs(opts :: any) do
		merged[k] = v
	end
	return merged :: FormatOptions
end

local function safePlayer(playerOrUserId: any): (Player?, number?)
	if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		local p = playerOrUserId :: Player
		return p, p.UserId
	elseif type(playerOrUserId) == "number" then
		local userId = playerOrUserId :: number
		return Players:GetPlayerByUserId(userId), userId
	elseif type(playerOrUserId) == "string" then
		local name = playerOrUserId :: string
		if name:sub(1, 1) == "@" then
			name = name:sub(2)
		end
		local ok, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(name)
		end)
		if ok and type(userId) == "number" then
			return Players:GetPlayerByUserId(userId), userId
		end
	end
	return nil, nil
end

local function getCache(userId: number): CachedUser
	local cached = userCache[userId]
	if not cached then
		cached = {}
		userCache[userId] = cached
	end
	return cached
end

local function tryFetchUserService(userId: number, entry: CachedUser)
	if not RunService:IsServer() then
		return
	end
	if entry._userServiceFetched then
		return
	end
	entry._userServiceFetched = true

	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync({ userId })
	end)
	if not ok or type(infos) ~= "table" or type(infos[1]) ~= "table" then
		return
	end

	local info = infos[1]
	if entry.username == nil and type(info.Username) == "string" then
		entry.username = info.Username
	end
	if entry.displayName == nil then
		if type(info.DisplayName) == "string" then
			entry.displayName = info.DisplayName
		elseif type(info.Username) == "string" then
			entry.displayName = info.Username
		end
	end
	if info.HasVerifiedBadge ~= nil then
		entry.verified = info.HasVerifiedBadge == true
	end
	if info.IsPremium ~= nil then
		entry.premium = info.IsPremium == true
	end
end

local function fillFromPlayer(player: Player, entry: CachedUser)
	entry.username = player.Name
	entry.displayName = player.DisplayName
	entry.premium = PlayerUtil.IsPremium(player)
	entry.verified = PlayerUtil.IsVerified(player)
end

local function getUserInfo(userId: number, player: Player?): CachedUser
	local entry = getCache(userId)
	if player then
		fillFromPlayer(player, entry)
		return entry
	end

	if entry.username == nil or entry.displayName == nil then
		tryFetchUserService(userId, entry)
	end

	if entry.username == nil then
		local okName, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if okName and type(name) == "string" then
			entry.username = name
		end
	end

	if entry.displayName == nil then
		local okDisp, displayName = pcall(function()
			return Players:GetDisplayNameAsync(userId)
		end)
		if okDisp and type(displayName) == "string" then
			entry.displayName = displayName
		end
	end

	if entry.username == nil then
		entry.username = "UserId:" .. tostring(userId)
	end
	if entry.displayName == nil then
		entry.displayName = entry.username
	end

	return entry
end

-- Public: return Roblox icons (handy for other systems)
function PlayerUtil.GetRobloxIcons(): { Verified: string, Premium: string, Robux: string }
	return {
		Verified = ICON_VERIFIED,
		Premium = ICON_PREMIUM,
		Robux = ICON_ROBUX,
	}
end

-- Returns whether a Player is Premium (player must be in-server)
function PlayerUtil.IsPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

-- Returns whether a Player has the Verified badge (player must be in-server)
function PlayerUtil.IsVerified(player: Player): boolean
	-- Property exists on modern Roblox Player, but keep it safe.
	local ok, value = pcall(function()
		return (player :: any).HasVerifiedBadge
	end)
	return ok and value == true
end

-- Gets badge state, cached (works with Player, userId, or username; off-server badges only on server)
function PlayerUtil.GetBadgeState(playerOrUserId: Player | number | string): BadgeState
	local player, userId = safePlayer(playerOrUserId)
	if not userId then
		return { premium = false, verified = false }
	end

	local cached = getCache(userId)
	if player then
		fillFromPlayer(player, cached)
	else
		if cached.verified == nil or cached.premium == nil then
			tryFetchUserService(userId, cached)
		end
	end

	return {
		premium = cached.premium == true,
		verified = cached.verified == true,
	}
end

-- Clears one cache entry (or everything if nil)
function PlayerUtil.ClearBadgeCache(userId: number?)
	if userId == nil then
		table.clear(userCache)
	else
		userCache[userId] = nil
	end
end

-- Returns "Username" or "DisplayName" for a player (no badges)
function PlayerUtil.GetBaseName(player: Player, useDisplayName: boolean?): string
	if useDisplayName then
		return player.DisplayName
	end
	return player.Name
end

-- Formats ONLY the DisplayName with badges (no username, no @)
function PlayerUtil.FormatDisplayName(playerOrUserId: Player | number | string, opts: FormatOptions?): string
	local options = mergeOptions(opts)

	local player, userId = safePlayer(playerOrUserId)
	if not userId then
		if type(playerOrUserId) == "string" then
			local name = playerOrUserId
			if name:sub(1, 1) == "@" then
				name = name:sub(2)
			end
			return name
		end
		return "Unknown"
	end

	local info = getUserInfo(userId, player)
	local baseName = info.displayName or ("UserId:" .. tostring(userId))

	local state = PlayerUtil.GetBadgeState(userId)

	local badges = {}
	if options.showPremium and state.premium then
		table.insert(badges, options.premiumIcon :: string)
	end
	if options.showVerified and state.verified then
		table.insert(badges, options.verifiedIcon :: string)
	end

	if #badges == 0 then
		return baseName
	end

	local sep = options.separator :: string
	local badgeStr = table.concat(badges, sep)

	if options.badgesBeforeName then
		return badgeStr .. sep .. baseName
	else
		return baseName .. sep .. badgeStr
	end
end

-- Formats name with optional @ and badges
function PlayerUtil.FormatUsername(playerOrUserId: Player | number | string, opts: FormatOptions?): string
	local options = mergeOptions(opts)

	local player, userId = safePlayer(playerOrUserId)
	if not userId then
		if type(playerOrUserId) == "string" then
			local name = playerOrUserId
			if name:sub(1, 1) == "@" then
				name = name:sub(2)
			end
			local base = name
			if options.includeAt then
				base = "@" .. base
			end
			return base
		end
		return "Unknown"
	end

	local baseName
	if player then
		baseName = PlayerUtil.GetBaseName(player, options.useDisplayName)
	else
		local info = getUserInfo(userId, player)
		baseName = if options.useDisplayName then info.displayName else info.username
	end

	if options.includeAt then
		baseName = "@" .. baseName
	end

	local state = PlayerUtil.GetBadgeState(userId)

	local badges = {}
	if options.showPremium and state.premium then
		table.insert(badges, options.premiumIcon :: string)
	end
	if options.showVerified and state.verified then
		table.insert(badges, options.verifiedIcon :: string)
	end

	if #badges == 0 then
		return baseName
	end

	local sep = options.separator :: string
	local badgeStr = table.concat(badges, sep)

	if options.badgesBeforeName then
		return badgeStr .. sep .. baseName
	else
		return baseName .. sep .. badgeStr
	end
end

-- Convenience: "DisplayName (@Username) [badges]"
function PlayerUtil.FormatDisplayAndUsername(player: Player, opts: FormatOptions?): string
	local options = mergeOptions(opts)

	local display = player.DisplayName
	local username = player.Name

	local state = PlayerUtil.GetBadgeState(player)

	local badges = {}
	if options.showPremium and state.premium then
		table.insert(badges, options.premiumIcon :: string)
	end
	if options.showVerified and state.verified then
		table.insert(badges, options.verifiedIcon :: string)
	end

	local sep = options.separator :: string
	local badgeStr = (#badges > 0) and (sep .. table.concat(badges, sep)) or ""

	if options.includeAt then
		return string.format("%s (@%s)%s", display, username, badgeStr)
	else
		return string.format("%s (%s)%s", display, username, badgeStr)
	end
end

-- Optional: auto-refresh cache as players join; also updates premium if it changes
function PlayerUtil.BindAutoCache()
	Players.PlayerAdded:Connect(function(p)
		userCache[p.UserId] = {
			username = p.Name,
			displayName = p.DisplayName,
			premium = PlayerUtil.IsPremium(p),
			verified = PlayerUtil.IsVerified(p),
		}

		-- Premium can change mid-session; keep cache fresh
		p:GetPropertyChangedSignal("MembershipType"):Connect(function()
			local entry = userCache[p.UserId]
			if entry then
				entry.premium = PlayerUtil.IsPremium(p)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(p)
		-- keep cached value for logs; call ClearBadgeCache(p.UserId) if you prefer cleanup
	end)
end

return PlayerUtil
