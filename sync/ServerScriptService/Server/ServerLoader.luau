local RS = game:GetService("ReplicatedStorage")
local Framework: any = require(RS.Framework :: ModuleScript)

local CanLoad = RS:WaitForChild('Client'):WaitForChild('CanLoad')



local function ensure(parent, className, name)
	local x = parent:FindFirstChild(name); if x then return x end
	local o = Instance.new(className); o.Name = name; o.Parent = parent; return o
end

local function ensureUnreliable(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local ok, inst = pcall(function()
		local u = Instance.new("UnreliableRemoteEvent")
		u.Name = name
		u.Parent = parent
		return u
	end)
	return ok and inst or nil
end

local Remotes  = ensure(RS, "Folder", "Remotes")
local CtrlRoot = ensure(Remotes, "Folder", "Controllers")
local Register = ensure(CtrlRoot, "RemoteEvent", "_Register")
local Ready    = ensure(CtrlRoot, "RemoteEvent", "_Ready")

Register.OnServerEvent:Connect(function(player, ctrlName: string, methods: {string})
	if type(ctrlName) ~= "string" or ctrlName == "" then
		return
	end
	if #ctrlName > 64 or not string.match(ctrlName, "^[%a_][%w_]*$") then
		return
	end
	if type(methods) ~= "table" then
		return
	end
	if #methods > 128 then
		return
	end

	local folder = ensure(CtrlRoot, "Folder", ctrlName)
	ensure(folder, "RemoteEvent", "_Requests")
	ensure(folder, "RemoteEvent", "_Responses")
	local evs  = ensure(folder, "Folder", "Events")
	local uevs = ensure(folder, "Folder", "UnreliableEvents")

	for _, m in ipairs(methods) do
		if type(m) == "string" and m ~= "" and #m <= 64 and string.match(m, "^[%a_][%w_]*$") then
			ensure(evs, "RemoteEvent", m)
			ensureUnreliable(uevs, m)
		end
	end

end)

Ready.OnServerEvent:Connect(function(player, ctrlName: string)
	if type(ctrlName) ~= "string" or ctrlName == "" then
		return
	end
	Framework:_markControllerReady(player, ctrlName)
end)


local ServiceClass = Framework.Components.Service

local function isClass(tbl: any): boolean
	return type(tbl) == "table"
		and type(tbl.new) == "function"
		and (
			type(rawget(tbl, "__className")) == "string"
			or type(rawget(tbl, "super")) == "table"
			or rawget(tbl, "__name") ~= nil
			or rawget(tbl, "__base") ~= nil
		)
end

local serviceModules = {}
for _, mod in ipairs(script.Parent.Services:GetDescendants()) do
	if mod:IsA("ModuleScript") then
		table.insert(serviceModules, mod)
	end
end

table.sort(serviceModules, function(a, b)
	return a:GetFullName() < b:GetFullName()
end)

for _, mod in ipairs(serviceModules) do
	local ret = require(mod :: ModuleScript)
	if type(ret) == "function" then
		ret = ret()
	end

	local instance

	if isClass(ret) then
		local Class = ret
		local name = mod.Name
		instance = Class:new(name)
		instance.Name = instance.Name or name
	elseif type(ret) == "table" then
		local name = ret.Name or mod.Name
		local Class = ServiceClass:Extend(name)
		Class.Client = Class.Client or {}
		if type(ret.Create) == "function" then Class.Create = ret.Create end
		if type(ret.Initialize) == "function" then Class.Initialize = ret.Initialize end
		if type(ret.Start) == "function" then Class.Start = ret.Start end
		if type(ret.Client) == "table" then
			for k, v in pairs(ret.Client) do
				Class.Client[k] = v
			end
		end
		for k, v in pairs(ret) do
			if k ~= "Name" and k ~= "Create" and k ~= "Initialize" and k ~= "Start" and k ~= "Client" and type(v) == "function" then
				Class[k] = v
			end
		end
		instance = Class:new(name)
	else
		error(("[Loader] %s must return a class or a spec table"):format(mod:GetFullName()))
	end

	Framework._bindService(instance)
	Framework._register("Service", instance)
	print(("[Loader] Bound service: %s"):format(instance.Name))
end

Framework._lifecycle()
CanLoad.Value = true
return Framework
