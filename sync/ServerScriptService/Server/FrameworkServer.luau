local RS          = game:GetService("ReplicatedStorage")
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local BaseComponent  = require(RS.Shared.Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local ConfigFile     = require(script.Parent.Config :: ModuleScript)

local Marshal        = require(RS.Shared.Utils.NetworkMarshal :: ModuleScript)

local okRL, RateLimiter = pcall(function() return require(script.Parent.Network.RateLimiter :: ModuleScript) end)
local okRC, RateConfig  = pcall(function() return require(script.Parent.Network.RateConfig :: ModuleScript)  end)
local _Gate = (okRL and RateLimiter and RateLimiter.new(okRC and RateConfig.default and RateConfig.default() or {})) or nil

local function _allowService(bucket, serviceName: string, method: string, player: Player)
	if not _Gate or not RateConfig or not RateConfig.forService then return true end
	local conf = RateConfig.forService(serviceName, method)
	if not conf then return true end
	local key = ("%d|service|%s|%s|%s"):format(player.UserId, bucket, serviceName, method)
	return select(1, _Gate:allow(key, 1, conf))
end

local function deepCopy(t)
	local r = {}
	for k,v in pairs(t) do r[k] = (type(v)=="table") and deepCopy(v) or v end
	return r
end
local function deepMerge(a,b)
	local r = deepCopy(a)
	for k,v in pairs(b) do
		if type(v)=="table" and type(r[k])=="table" then
			r[k] = deepMerge(r[k], v)
		else
			r[k] = v
		end
	end
	return r
end

local SharedCfg = ConfigFile.Shared or {}
local ServerOnly = {}
for k,v in pairs(ConfigFile) do
	if k ~= "Shared" then ServerOnly[k] = v end
end
local ServerConfig = deepMerge(SharedCfg, ServerOnly)

local function ensure(parent: Instance, className: string, name: string): Instance
	local x = parent:FindFirstChild(name)
	if x then return x end
	local o = Instance.new(className)
	o.Name = name; o.Parent = parent
	return o
end

-- ============================================================
-- Mirror shared config to clients through a JSON-safe StringValue.
-- ============================================================

do
	local cfgFolder = ensure(RS, "Folder", "FrameworkConfig")
	local sv = cfgFolder:FindFirstChild("Shared") :: StringValue
	if not sv then
		sv = Instance.new("StringValue"); sv.Name = "Shared"; sv.Parent = cfgFolder
	end

	-- Encode Roblox datatypes (Color3, EnumItem, etc.) before JSON.
	local ConfigCodec = require(RS.Shared.Utils.ConfigCodec :: ModuleScript)
	sv.Value = HttpService:JSONEncode(ConfigCodec.Encode(SharedCfg))
end

local function buildServiceMap(services)
	local t = {}
	for _, n in ipairs(services) do
		local ok, s = pcall(game.GetService, game, n.Name)
		if ok and s then t[n.Name] = s end
	end
	return t
end

local function lazy2(shared, server)
	return setmetatable({}, {
		__index = function(_, key)
			local m = (server and server:FindFirstChild(key, true)) or (shared and shared:FindFirstChild(key, true))
			assert(m and m:IsA("ModuleScript"), ("Missing module %s"):format(key))
			return require(m :: ModuleScript)
		end
	})
end
local SharedRoot = RS:FindFirstChild("Shared")
local ServerRoot = script.Parent

local Packages   = lazy2(SharedRoot and SharedRoot:FindFirstChild("Packages"), ServerRoot:FindFirstChild("Packages"))
local Utilities  = lazy2(SharedRoot and SharedRoot:FindFirstChild("Utils"),     ServerRoot:FindFirstChild("Utils"))
local Components = lazy2(SharedRoot and SharedRoot:FindFirstChild("Components"), ServerRoot:FindFirstChild("Components"))

local Framework = {}
Framework.__kind        = "server"
Framework.Config        = ServerConfig
Framework.Packages      = Packages
Framework.Utils         = Utilities
Framework.Utilities     = Utilities
Framework.References    = buildServiceMap(game:GetChildren())
for name, svc in pairs(Framework.References) do Framework[name] = svc; Framework[string.lower(name)] = svc end
Framework.Components    = Components
Framework.BaseComponent = BaseComponent
if BaseComponent.SetFramework then
	BaseComponent.SetFramework(Framework)
end

function Framework:CreateService(name: string)
	local Service = Components.Service:new(name)
	return Service
end
function Framework:CreateController(name: string)
	local Controller = Components.Controller:new(name)
	return Controller
end

local _services: {[string]: any} = {}
local _controllers: {[string]: any} = {}
local _controllerProxies: {[string]: any} = {}

local Remotes = ensure(RS, "Folder", "Remotes")
local SvcRoot = ensure(Remotes, "Folder", "Services")
local CtrlRoot= ensure(Remotes, "Folder", "Controllers")

-- Controller readiness + queued events (server->client)
local CtrlQueueMax = (ServerConfig and ServerConfig.ControllerEventQueueMax) or 100
local _ctrlReady: {[Player]: {[string]: boolean}} = {}
local _ctrlQueues: {[Player]: {[string]: { [number]: {method: string, enc: {any}, n: number, unreliable: boolean} }}} = {}
local _ctrlReadySignals: {[Player]: {[string]: BindableEvent}} = {}

local function isCtrlReady(plr: Player, ctrlName: string): boolean
	local per = _ctrlReady[plr]
	return per ~= nil and per[ctrlName] == true
end

local function getCtrlReadySignal(plr: Player, ctrlName: string): BindableEvent
	local per = _ctrlReadySignals[plr]
	if not per then
		per = {}
		_ctrlReadySignals[plr] = per
	end
	local ev = per[ctrlName]
	if not ev then
		ev = Instance.new("BindableEvent")
		per[ctrlName] = ev
	end
	return ev
end

local function enqueueCtrlEvent(plr: Player, ctrlName: string, method: string, enc: {any}, n: number, unreliable: boolean)
	local per = _ctrlQueues[plr]
	if not per then
		per = {}
		_ctrlQueues[plr] = per
	end
	local q = per[ctrlName]
	if not q then
		q = {}
		per[ctrlName] = q
	end
	if #q >= CtrlQueueMax then
		warn(("[Controller %s] Dropping queued event '%s' for %s (queue full)"):format(ctrlName, method, plr.Name))
		return
	end
	table.insert(q, { method = method, enc = enc, n = n, unreliable = unreliable })
end

local function makeUnreliable(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local ok, inst = pcall(function()
		local u = Instance.new("UnreliableRemoteEvent")
		u.Name = name; u.Parent = parent
		return u
	end)
	return ok and inst or nil
end

-- Get the class table for a BaseComponent instance across old/new metatable styles.
local function getClassTable(obj: any): any
	local sup = rawget(obj, "super")
	if type(sup) == "table" then
		return sup
	end

	local mt = getmetatable(obj)
	if type(mt) == "table" then
		if type(mt.__index) == "table" then
			return mt.__index
		end
		return mt
	end

	return obj
end

local function bindServiceInstance(serviceObj: any)
	local svcFolder = ensure(SvcRoot, "Folder", serviceObj.__class or serviceObj.Name)
	local fnFolder  = ensure(svcFolder, "Folder", "Functions")
	local evFolder  = ensure(svcFolder, "Folder", "Events")
	local uevFolder = ensure(svcFolder, "Folder", "UnreliableEvents")
	local reqEvent  = ensure(svcFolder, "RemoteEvent", "_Requests") :: RemoteEvent
	local resEvent  = ensure(svcFolder, "RemoteEvent", "_Responses") :: RemoteEvent

	local klass = getClassTable(serviceObj)

	local clientDefs = {}
	local classClientDefs = type(klass) == "table" and rawget(klass, "Client") or nil
	if type(classClientDefs) == "table" then
		for key, value in pairs(classClientDefs) do
			clientDefs[key] = value
		end
	end

	local instanceClientDefs = rawget(serviceObj, "Client")
	if type(instanceClientDefs) == "table" then
		for key, value in pairs(instanceClientDefs) do
			clientDefs[key] = value
		end
	end

	for method, fn in pairs(clientDefs) do
		if type(fn) == "function" then
			local rf = ensure(fnFolder, "RemoteFunction", method)
			local re = ensure(evFolder, "RemoteEvent",   method)
			makeUnreliable(uevFolder, method)

			rf.OnServerInvoke = function(player: Player, ...)
				if not _allowService("rpc", serviceObj.Name, method, player) then return nil end
				local args = table.pack(...)
				for i=1,args.n do
					args[i] = Marshal.Decode(args[i])
				end
				local ok, result = pcall(fn, serviceObj, player, table.unpack(args,1,args.n))
				if not ok then
					warn(("[RF %s.%s] %s"):format(serviceObj.Name, method, tostring(result)))
					return nil
				end
				return Marshal.Encode(result)
			end

			re.OnServerEvent:Connect(function(player: Player, ...)
				if not _allowService("event", serviceObj.Name, method, player) then return end
				local args = table.pack(...)
				for i=1,args.n do
					args[i] = Marshal.Decode(args[i])
				end
				local ok, err = pcall(fn, serviceObj, player, table.unpack(args,1,args.n))
				if not ok then
					warn(("[RE %s.%s] %s"):format(serviceObj.Name, method, tostring(err)))
				end
			end)
		end
	end

	-- Awaitable RPCs over RemoteEvents (request/response)
	reqEvent.OnServerEvent:Connect(function(player: Player, method: string, id: string, ...)
		if type(method) ~= "string" or type(id) ~= "string" then return end
		if not _allowService("rpc", serviceObj.Name, method, player) then
			resEvent:FireClient(player, id, false, "RateLimited")
			return
		end

		local fn = clientDefs[method]
		if type(fn) ~= "function" then
			resEvent:FireClient(player, id, false, "Unknown method")
			return
		end

		local args = table.pack(...)
		for i = 1, args.n do
			args[i] = Marshal.Decode(args[i])
		end

		local ok, result = pcall(fn, serviceObj, player, table.unpack(args, 1, args.n))
		if not ok then
			warn(("[Await %s.%s] %s"):format(serviceObj.Name, method, tostring(result)))
			resEvent:FireClient(player, id, false, tostring(result))
			return
		end

		local enc = Marshal.Encode(result)
		resEvent:FireClient(player, id, true, enc)
	end)

	function serviceObj:Event(eventName: string)
		local re = evFolder:FindFirstChild(eventName)
		if not re then
			re = Instance.new("RemoteEvent"); re.Name = eventName; re.Parent = evFolder
			makeUnreliable(uevFolder, eventName)
		end
		return {
			Fire = function(_, plr: Player, ...) re:FireClient(plr, ...) end,
			All  = function(_, ...) re:FireAllClients(...) end,
			Raw  = re,
		}
	end
end

local __ctrlState: {[string]: {
	events: Instance, uevs: Instance, req: RemoteEvent, res: RemoteEvent,
	pending: {[Player]: {[string]: {resolve:(any)->(), reject:(any)->()}}}
}} = {}

local function ctrlState(ctrlName: string)
	local folder = ensure(CtrlRoot, "Folder", ctrlName)
	local events = ensure(folder, "Folder", "Events")
	local uevs   = ensure(folder, "Folder", "UnreliableEvents")
	local req    = ensure(folder, "RemoteEvent", "_Requests") :: RemoteEvent
	local res    = ensure(folder, "RemoteEvent", "_Responses") :: RemoteEvent

	local state = __ctrlState[ctrlName]
	if state then return state end

	state = { events = events, uevs = uevs, req = req, res = res, pending = {} }
	__ctrlState[ctrlName] = state

	res.OnServerEvent:Connect(function(player: Player, method: string, id: string, ok: boolean, value: any)
		local pendPlr = state.pending[player]; if not pendPlr then return end
		local entry = pendPlr[id]; if not entry then return end
		pendPlr[id] = nil
		if ok then entry.resolve(value) else entry.reject(value) end
	end)

	return state
end

local function flushCtrlQueue(plr: Player, ctrlName: string)
	local per = _ctrlQueues[plr]
	if not per then
		return
	end
	local q = per[ctrlName]
	if not q or #q == 0 then
		return
	end
	per[ctrlName] = nil

	local state = ctrlState(ctrlName)
	for _, item in ipairs(q) do
		if item.unreliable then
			local ev = state.uevs:FindFirstChild(item.method)
			if not ev then
				ev = makeUnreliable(state.uevs, item.method)
			end
			if ev then
				local unreliable = ev :: any
				unreliable:FireClient(plr, table.unpack(item.enc, 1, item.n))
			else
				local remote = ensure(state.events, "RemoteEvent", item.method) :: RemoteEvent
				remote:FireClient(plr, table.unpack(item.enc, 1, item.n))
			end
		else
			local remote = ensure(state.events, "RemoteEvent", item.method) :: RemoteEvent
			remote:FireClient(plr, table.unpack(item.enc, 1, item.n))
		end
	end
end

local function buildServerControllerProxy(ctrlName: string)
	local state = ctrlState(ctrlName)

	local proxy = { Server = {} }
	proxy.Server.Fire               = {}
	proxy.Server.FireAll            = {}
	proxy.Server.FireUnreliable     = {}
	proxy.Server.FireUnreliableAll  = {}

	local function encodeArgs(...)
		local raw = table.pack(...)
		local enc = table.create(raw.n)
		for i = 1, raw.n do
			local value = raw[i]
			enc[i] = if typeof(value) == "Instance" then value else Marshal.Encode(value)
		end
		return enc, raw.n
	end

	local function sendOrQueue(plr: Player, method: string, enc: {any}, n: number, unreliable: boolean)
		if not isCtrlReady(plr, ctrlName) then
			enqueueCtrlEvent(plr, ctrlName, method, enc, n, unreliable)
			return
		end

		if unreliable then
			local ev = state.uevs:FindFirstChild(method)
			if not ev then
				ev = makeUnreliable(state.uevs, method)
			end
			if ev then
				local unreliable = ev :: any
				unreliable:FireClient(plr, table.unpack(enc, 1, n))
			else
				local remote = ensure(state.events, "RemoteEvent", method) :: RemoteEvent
				remote:FireClient(plr, table.unpack(enc, 1, n))
			end
		else
			local remote = ensure(state.events, "RemoteEvent", method) :: RemoteEvent
			remote:FireClient(plr, table.unpack(enc, 1, n))
		end
	end

	setmetatable(proxy.Server.Fire, {
		__index = function(_, method: string)
			return function(_, plr: Player, ...)
				local enc, n = encodeArgs(...)
				sendOrQueue(plr, method, enc, n, false)
			end
		end
	})

	setmetatable(proxy.Server.FireAll, {
		__index = function(_, method: string)
			return function(_, ...)
				local enc, n = encodeArgs(...)
				for _, plr in ipairs(Players:GetPlayers()) do
					sendOrQueue(plr, method, enc, n, false)
				end
			end
		end
	})

	setmetatable(proxy.Server.FireUnreliable, {
		__index = function(_, method: string)
			return function(_, plr: Player, ...)
				local enc, n = encodeArgs(...)
				sendOrQueue(plr, method, enc, n, true)
			end
		end
	})

	setmetatable(proxy.Server.FireUnreliableAll, {
		__index = function(_, method: string)
			return function(_, ...)
				local enc, n = encodeArgs(...)
				for _, plr in ipairs(Players:GetPlayers()) do
					sendOrQueue(plr, method, enc, n, true)
				end
			end
		end
	})

	return proxy
end

function Framework:GetService(name: string)
	local s = _services[name]; assert(s, "No service: "..name); return s
end
function Framework:GetController(name: string)
	local proxy = _controllerProxies[name]
	if proxy ~= nil then
		return proxy
	end

	proxy = buildServerControllerProxy(name)
	_controllerProxies[name] = proxy
	return proxy
end

function Framework:_markControllerReady(player: Player, ctrlName: string)
	local per = _ctrlReady[player]
	if not per then
		per = {}
		_ctrlReady[player] = per
	end
	per[ctrlName] = true

	local sigs = _ctrlReadySignals[player]
	if sigs and sigs[ctrlName] then
		sigs[ctrlName]:Fire()
	end

	flushCtrlQueue(player, ctrlName)
end

function Framework:IsControllerReady(player: Player, ctrlName: string): boolean
	return isCtrlReady(player, ctrlName)
end

function Framework:WaitForController(player: Player, ctrlName: string, timeout: number?): boolean
	if isCtrlReady(player, ctrlName) then
		return true
	end
	local ev = getCtrlReadySignal(player, ctrlName)
	local done = false
	local conn = ev.Event:Connect(function()
		done = true
	end)

	local deadline = os.clock() + (timeout or 5)
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	conn:Disconnect()
	return isCtrlReady(player, ctrlName)
end

function Framework._register(kind: "Service"|"Controller", obj: any)
	if kind == "Service" then
		assert(not _services[obj.Name], "Duplicate service: "..obj.Name)
		_services[obj.Name] = obj
	else
		assert(not _controllers[obj.Name], "Duplicate controller: "..obj.Name)
		_controllers[obj.Name] = obj
	end
end
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

function Framework._lifecycle()
	for _, svc in ipairs(sortedByName(_services)) do
		if svc.Initialize then
			svc:Initialize()
			print('[Loader] Initialized service: ' .. svc.Name)
		end
	end
	for _, svc in ipairs(sortedByName(_services)) do
		if svc.Start      then
			svc:Start()
			print('[Loader] Started service: ' .. svc.Name)
		end
	end
end
function Framework._bindService(obj: any) bindServiceInstance(obj) end

Players.PlayerRemoving:Connect(function(plr)
	_ctrlReady[plr] = nil
	_ctrlQueues[plr] = nil
	local sigs = _ctrlReadySignals[plr]
	if sigs then
		for _, ev in pairs(sigs) do
			ev:Destroy()
		end
	end
	_ctrlReadySignals[plr] = nil
	for _, state in pairs(__ctrlState) do
		state.pending[plr] = nil
	end
end)

return Framework
