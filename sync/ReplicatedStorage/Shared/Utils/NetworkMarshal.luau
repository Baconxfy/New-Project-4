local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local M = {}


local INSTANCE_RESOLVE_TIMEOUT = 2
local INSTANCE_REF_TAG = "__NM_InstanceRef"
local INSTANCE_REF_ATTR = "__NM_RefId"
local InstanceRegistry: { [string]: Instance } = {}
setmetatable(InstanceRegistry, { __mode = "v" })

local function indexTaggedInstances()
	for _, inst in ipairs(CollectionService:GetTagged(INSTANCE_REF_TAG)) do
		local id = inst:GetAttribute(INSTANCE_REF_ATTR)
		if type(id) == "string" then
			InstanceRegistry[id] = inst
		end
	end
end

indexTaggedInstances()

CollectionService:GetInstanceAddedSignal(INSTANCE_REF_TAG):Connect(function(inst)
	local id = inst:GetAttribute(INSTANCE_REF_ATTR)
	if type(id) == "string" then
		InstanceRegistry[id] = inst
	end
end)

CollectionService:GetInstanceRemovedSignal(INSTANCE_REF_TAG):Connect(function(inst)
	local id = inst:GetAttribute(INSTANCE_REF_ATTR)
	if type(id) == "string" and InstanceRegistry[id] == inst then
		InstanceRegistry[id] = nil
	end
end)

local function ensureInstanceId(inst: Instance): string
	local id = inst:GetAttribute(INSTANCE_REF_ATTR)
	if type(id) ~= "string" and RunService:IsServer() then
		id = HttpService:GenerateGUID(false)
		inst:SetAttribute(INSTANCE_REF_ATTR, id)
	end
	if type(id) == "string" then
		if RunService:IsServer() and not CollectionService:HasTag(inst, INSTANCE_REF_TAG) then
			CollectionService:AddTag(inst, INSTANCE_REF_TAG)
		end
		InstanceRegistry[id] = inst
	end
	return id
end

----------------------------------------------------------------------
-- Instance path tokens
----------------------------------------------------------------------

local function isInstToken(v: any): boolean
	return type(v) == "table"
		and rawget(v, "__inst") == true
		and (type(rawget(v, "parts")) == "table" or type(rawget(v, "id")) == "string")
end

local function getPathParts(inst: Instance): {string}?
	-- Builds a stable path as array parts: {"Workspace","Model","Part"}
	-- This avoids GetFullName() + "." splitting issues.
	local parts = {}
	local cur: Instance? = inst

	-- Must be parented somewhere under game to be resolvable remotely
	while cur and cur ~= game do
		table.insert(parts, cur.Name)
		cur = cur.Parent
	end

	if cur ~= game then
		return nil
	end

	-- reverse
	for i = 1, math.floor(#parts / 2) do
		local j = #parts - i + 1
		parts[i], parts[j] = parts[j], parts[i]
	end

	return parts
end

local function getRoot(parts: {string}): Instance?
	local rootName = parts[1]
	if rootName == "Workspace" then
		return workspace
	elseif rootName == "Players" then
		return game:GetService("Players")
	else
		local ok, svc = pcall(function()
			return game:GetService(rootName)
		end)
		return ok and svc or nil
	end
end

local function resolvePartsNow(parts: {string}): Instance?
	if #parts == 0 then return nil end
	local current = getRoot(parts)
	if not current then return nil end

	for i = 2, #parts do
		current = current:FindFirstChild(parts[i])
		if not current then return nil end
	end
	return current
end

local function resolvePartsWaitClient(parts: {string}, timeout: number): Instance?
	-- Waits as little as possible: WaitForChild wakes immediately when replicated,
	-- but we cap total wait to `timeout`.
	if #parts == 0 then return nil end

	local current = getRoot(parts)
	if not current then return nil end

	local deadline = os.clock() + timeout

	for i = 2, #parts do
		local remaining = deadline - os.clock()
		if remaining <= 0 then
			return nil
		end

		-- WaitForChild returns immediately if already exists; otherwise waits up to remaining
		current = current:WaitForChild(parts[i], remaining)
		if not current then
			return nil
		end
	end

	return current
end

local function resolveIdNow(id: string): Instance?
	local inst = InstanceRegistry[id]
	if inst and inst.Parent then
		return inst
	end
	return nil
end

local function resolveIdWaitClient(id: string, timeout: number): Instance?
	local inst = InstanceRegistry[id]
	if inst and inst.Parent then
		return inst
	end

	local deadline = os.clock() + timeout
	repeat
		inst = InstanceRegistry[id]
		if inst and inst.Parent then
			return inst
		end
		task.wait()
	until os.clock() >= deadline

	return nil
end

----------------------------------------------------------------------
-- Encode / Decode
----------------------------------------------------------------------

local function encodeAny(v: any, visited: {[any]: any}?): any
	local tv = typeof(v)

	if tv == "Instance" then
		local inst = v :: Instance
		local id = ensureInstanceId(inst)
		if type(id) == "string" then
			return { __inst = true, id = id }
		end
		local parts = getPathParts(inst)
		if parts then
			return { __inst = true, parts = parts }
		end
		-- Not safely representable (e.g., unparented client-only); return nil so you can handle it
		return nil
	end

	if type(v) ~= "table" then
		return v
	end

	if isInstToken(v) then
		return v
	end

	local seen = visited
	if seen == nil then
		seen = {} :: {[any]: any}
		setmetatable(seen, { __mode = "k" })
	end
	if seen[v] ~= nil then
		return seen[v]
	end

	local out = {}
	seen[v] = out
	for k, val in pairs(v) do
		out[encodeAny(k, seen)] = encodeAny(val, seen)
	end
	return out
end

local function decodeAny(v: any, _resolver: ((string, string) -> any)?, visited: {[any]: any}?): any
	if isInstToken(v) then
		local id = rawget(v, "id")
		if type(id) == "string" then
			if RunService:IsClient() then
				return resolveIdWaitClient(id, INSTANCE_RESOLVE_TIMEOUT)
			else
				return resolveIdNow(id)
			end
		end

		local parts = v.parts :: {string}
		if RunService:IsClient() then
			return resolvePartsWaitClient(parts, INSTANCE_RESOLVE_TIMEOUT)
		else
			return resolvePartsNow(parts)
		end
	end

	if type(v) ~= "table" then
		return v
	end

	local seen = visited
	if seen == nil then
		seen = {} :: {[any]: any}
		setmetatable(seen, { __mode = "k" })
	end
	if seen[v] ~= nil then
		return seen[v]
	end

	local out = {}
	seen[v] = out
	for k, val in pairs(v) do
		out[decodeAny(k, _resolver, seen)] = decodeAny(val, _resolver, seen)
	end
	return out
end

function M.Encode(v: any): any
	return encodeAny(v, nil)
end

function M.Decode(v: any, resolver: ((string, string) -> any)?): any
	return decodeAny(v, resolver, nil)
end

return M
