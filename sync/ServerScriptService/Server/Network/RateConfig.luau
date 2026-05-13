local ServerRoot = script.Parent.Parent
local Config = require(ServerRoot.Config :: ModuleScript)

local RateConfig = {}

local RL = (Config and (Config.RateLimits or (Config.Shared and Config.Shared.RateLimits))) or {}
local Default = RL.Default -- may be nil; we handle that downstream

-- Normalize a config table into {capacity, refill, every}
local function tb(c)
	if type(c) ~= "table" then
		return nil
	end

	local cap = tonumber(c.capacity) or tonumber(c.burst)
	if not cap or cap <= 0 then
		return { capacity = 0, refill = 0, every = tonumber(c.every) or 1 }
	end

	local refill = tonumber(c.refill) or cap
	local every = tonumber(c.every) or 1
	if refill < 0 then
		refill = 0
	end
	if every <= 0 then
		every = 1
	end

	return { capacity = cap, refill = refill, every = every }
end

function RateConfig.default()
	return tb(Default) or { capacity = 20, refill = 10, every = 1 }
end

-- Service keys:
-- ["*"]
-- ["InventoryService/*"]
-- ["InventoryService/Client/*"]
-- ["InventoryService/Client/AddItem"]
function RateConfig.forService(serviceName, method)
	local group = RL.Service or {}

	local exact = group[("%s/Client/%s"):format(serviceName, method)]
	local svcAllClient = group[("%s/Client/*"):format(serviceName)]
	local svcAll = group[("%s/*"):format(serviceName)]
	local any = group["*"]

	return tb(exact) or tb(svcAllClient) or tb(svcAll) or tb(any) or RateConfig.default()
end

return RateConfig
