local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return require(game.ServerScriptService.Server.FrameworkServer :: ModuleScript)
end

local Marshal = require(RS.Shared.Utils.NetworkMarshal :: ModuleScript)

local HttpService = game:GetService("HttpService")
local BaseComponent = require(RS.Shared.Components:FindFirstChild("BaseComponent", true) :: ModuleScript)
local ControllerBase = require(RS.Shared.Components:FindFirstChild("Controller", true) :: ModuleScript)

local cfgFolder = RS:WaitForChild("FrameworkConfig")
local sv = cfgFolder:WaitForChild("Shared") :: StringValue

local ConfigCodec = require(RS.Shared.Utils.ConfigCodec :: ModuleScript)
local ClientConfig = ConfigCodec.Decode(HttpService:JSONDecode(sv.Value))

local function buildServiceMap(services)
	local t = {}
	for _, n in ipairs(services) do
		local ok, s = pcall(game.GetService, game, n.Name)
		if ok and s then
			t[n.Name] = s
		end
	end
	return t
end

-- Lazy loader for Shared/ folders
local function lazyShared(folderName: string)
	local folder = RS:WaitForChild("Shared"):FindFirstChild(folderName)
	return setmetatable({}, {
		__index = function(_, key: string)
			if type(key) == "string" and key:sub(1, 2) == "__" then
				return nil
			end
			local m = folder and folder:FindFirstChild(key, true)
			assert(m and m:IsA("ModuleScript"), ("Missing %s/%s"):format(folderName, key))
			return require(m :: ModuleScript)
		end,
	})
end

local Framework = {}
Framework.__kind = "client"
Framework.Config = ClientConfig
Framework.Packages = lazyShared("Packages")
Framework.Utils = lazyShared("Utils")
Framework.Components = lazyShared("Components")

local Promise = Framework.Packages.Promise

Framework.References = buildServiceMap(game:GetChildren())
for name, svc in pairs(Framework.References) do
	Framework[name] = svc
	Framework[string.lower(name)] = svc
end

Framework.BaseComponent = BaseComponent
if BaseComponent.SetFramework then
	BaseComponent.SetFramework(Framework)
end

function Framework:CreateController(name: string)
	local Class = ControllerBase:new(name)
	return Class
end

local _controllers: { [string]: any } = {}
local _serviceProxies: { [string]: any } = {}

local function sortedByName(map)
	local list = {}
	for _, value in pairs(map) do
		table.insert(list, value)
	end
	table.sort(list, function(a, b)
		return tostring(a.Name) < tostring(b.Name)
	end)
	return list
end

local function encodeArgs(...)
	local raw = table.pack(...)
	local out = table.create(raw.n)
	for i = 1, raw.n do
		out[i] = Marshal.Encode(raw[i])
	end
	return out, raw.n
end

local function buildClientServiceProxy(serviceName: string)
	local root = RS:WaitForChild("Remotes")
	local svc = root:WaitForChild("Services"):WaitForChild(serviceName)
	local fns = svc:WaitForChild("Functions")
	local evs = svc:WaitForChild("Events")
	local uevs = svc:FindFirstChild("UnreliableEvents")
	local req = svc:WaitForChild("_Requests") :: RemoteEvent
	local res = svc:WaitForChild("_Responses") :: RemoteEvent

	local pending: { [string]: { resolve: (any) -> (), reject: (any) -> () } } = {}
	res.OnClientEvent:Connect(function(id: string, ok: boolean, value: any)
		local entry = pending[id]
		if not entry then
			return
		end
		pending[id] = nil
		if ok then
			entry.resolve(Marshal.Decode(value))
		else
			entry.reject(value)
		end
	end)

	local proxy = { Fire = {}, FireUnreliable = {}, await = {} }

	setmetatable(proxy, {
		__index = function(_, method: string)
			local rf = fns:FindFirstChild(method)
			if rf then
				return function(_, ...)
					local encArgs, n = encodeArgs(...)
					local v = (rf :: RemoteFunction):InvokeServer(table.unpack(encArgs, 1, n))
					return Marshal.Decode(v)
				end
			end
			local re = evs:FindFirstChild(method)
			if re then
				return function(self, ...)
					local encArgs, n = encodeArgs(...)
					local remote = re :: RemoteEvent
					remote:FireServer(table.unpack(encArgs, 1, n))
				end
			end
			error(("[Service %s] No remote for '%s'"):format(serviceName, method))
		end,
	})

	setmetatable(proxy.Fire, {
		__index = function(_, method: string)
			local re = evs:FindFirstChild(method)
			assert(re, ("[Service %s] No Event '%s'"):format(serviceName, method))
			return function(self, ...)
				local encArgs, n = encodeArgs(...)
				local remote = re :: RemoteEvent
				remote:FireServer(table.unpack(encArgs, 1, n))
			end
		end,
	})

	setmetatable(proxy.FireUnreliable, {
		__index = function(_, method: string)
			local ure = uevs and uevs:FindFirstChild(method)
			if ure then
				return function(self, ...)
					local encArgs, n = encodeArgs(...)
					local unreliable = ure :: any
					unreliable:FireServer(table.unpack(encArgs, 1, n))
				end
			end
			local re = evs:FindFirstChild(method)
			assert(re, ("[Service %s] No Event '%s'"):format(serviceName, method))
			return function(self, ...)
				local encArgs, n = encodeArgs(...)
				local remote = re :: RemoteEvent
				remote:FireServer(table.unpack(encArgs, 1, n))
			end
		end,
	})

	setmetatable(proxy.await, {
		__index = function(_, method: string)
			local rf = fns:FindFirstChild(method)
			assert(rf, ("[Service %s] No RemoteFunction '%s' to await"):format(serviceName, method))
			return function(_, ...)
				local encArgs, n = encodeArgs(...)

				local id = HttpService:GenerateGUID(false)
				local ok, val = Promise.new(function(resolve, reject)
					pending[id] = { resolve = resolve, reject = reject }
					req:FireServer(method, id, table.unpack(encArgs, 1, n))
				end):await()
				return val, ok
			end
		end,
	})

	proxy.Client = proxy
	proxy.Client.Fire = proxy.Fire
	proxy.Client.FireUnreliable = proxy.FireUnreliable
	proxy.Client.await = proxy.await

	return proxy
end

function Framework:GetService(name: string)
	local proxy = _serviceProxies[name]
	if proxy ~= nil then
		return proxy
	end

	proxy = buildClientServiceProxy(name)
	_serviceProxies[name] = proxy
	return proxy
end

function Framework:GetController(name: string)
	local inst = _controllers[name]
	assert(inst, "No controller: " .. name)
	return inst
end

function Framework._register(kind: "Service" | "Controller", obj: any)
	assert(kind == "Controller", "Clients only register controllers")
	assert(not _controllers[obj.Name], "Duplicate controller: " .. obj.Name)
	_controllers[obj.Name] = obj
end

function Framework._lifecycle()
	for _, ctrl in ipairs(sortedByName(_controllers)) do
		if ctrl.Initialize then
			ctrl:Initialize()
			print("[Loader] Initialized controller: " .. ctrl.Name)
		end
	end
	for _, ctrl in ipairs(sortedByName(_controllers)) do
		if ctrl.Start then
			ctrl:Start()
			print("[Loader] Started controller: " .. ctrl.Name)
		end
	end
end

return Framework
