local RS        = game:GetService("ReplicatedStorage")
repeat
	task.wait()
until RS:WaitForChild('Client'):WaitForChild('CanLoad').Value == true

local Framework: any = require(RS.Framework :: ModuleScript)

local Marshal    = require(RS.Shared.Utils.NetworkMarshal :: ModuleScript)




local Remotes  = RS:FindFirstChild("Remotes") or Instance.new("Folder", RS)
Remotes.Name = "Remotes"
local CtrlRoot = Remotes:FindFirstChild("Controllers") or Instance.new("Folder", Remotes)
CtrlRoot.Name = "Controllers"
local Ready = CtrlRoot:WaitForChild("_Ready") :: RemoteEvent
local ReadyControllers = {}

local function decodeArgsIntoArray(...)
	local raw = table.pack(...)

	local args = table.create(raw.n)
	for i = 1, raw.n do
		args[i] = Marshal.Decode(raw[i])
	end
	return args, raw.n
end


local function getClassTable(obj: any): any
	-- New BaseComponent puts the class on the instance
	local sup = rawget(obj, "super")
	if type(sup) == "table" then
		return sup
	end

	-- Older versions / fallback
	local mt = getmetatable(obj)
	if type(mt) == "table" then
		if type(mt.__index) == "table" then
			return mt.__index
		end
		return mt
	end

	return obj
end

local function attachController(ctrlObj)
	Framework._register("Controller", ctrlObj)
	print(("[Loader] Bound controller: %s"):format(ctrlObj.Name))

	local host = ctrlObj
	-- Class table is no longer always getmetatable(host).__index.
	local klass = getClassTable(host)
	local serverDefs = {}
	local classServerDefs = type(klass) == "table" and rawget(klass, "Server") or nil
	if type(classServerDefs) == "table" then
		for key, value in pairs(classServerDefs) do
			serverDefs[key] = value
		end
	end
	local instanceServerDefs = rawget(host, "Server")
	if type(instanceServerDefs) == "table" then
		for key, value in pairs(instanceServerDefs) do
			serverDefs[key] = value
		end
	end

	local methods = {}
	for k, v in pairs(serverDefs) do
		if type(v) == "function" then
			table.insert(methods, k)
		end
	end

	local Register = CtrlRoot:FindFirstChild("_Register") or Instance.new("RemoteEvent", CtrlRoot)
	Register.Name = "_Register"
	Register:FireServer(host.Name, methods)
	ReadyControllers[#ReadyControllers + 1] = host.Name

	local folder   = CtrlRoot:WaitForChild(host.Name)
	local evFolder = folder:WaitForChild("Events")

	for _, m in ipairs(methods) do
		local re = evFolder:WaitForChild(m) :: RemoteEvent
		re.OnClientEvent:Connect(function(...)
			local args, n = decodeArgsIntoArray(...)
			local fn = serverDefs[m]
			if type(fn) == "function" then
				local ok, err = pcall(fn, host, table.unpack(args, 1, n))
				if not ok then
					warn(("[Controller %s.%s] %s"):format(host.Name, m, tostring(err)))
				end
			end
		end)
	end

	local req = folder:WaitForChild("_Requests") :: RemoteEvent
	local res = folder:WaitForChild("_Responses") :: RemoteEvent

	req.OnClientEvent:Connect(function(method: string, id: string, ...)
		local args, n = decodeArgsIntoArray(...)
		local fn = serverDefs[method]
		if type(fn) ~= "function" then
			res:FireServer(method, id, false, "Unknown method")
			return
		end
		local ok, value = pcall(fn, host, table.unpack(args, 1, n))
		if ok then
			local enc = Marshal.Encode(value)
			res:FireServer(method, id, true, enc)
		else
			res:FireServer(method, id, false, tostring(value))
		end
	end)

end

local folder = script.Parent and script.Parent.Controllers or RS:WaitForChild("Client"):WaitForChild("Controllers")
local modules = {}
for _, mod in ipairs(folder:GetDescendants()) do
	if mod:IsA("ModuleScript") then
		table.insert(modules, mod)
	end
end

table.sort(modules, function(a, b)
	return a:GetFullName() < b:GetFullName()
end)

for _, mod in ipairs(modules) do
	local Controller = require(mod :: ModuleScript)
	attachController(Controller)
end

Framework._lifecycle()
for _, ctrlName in ipairs(ReadyControllers) do
	Ready:FireServer(ctrlName)
	print(("[Loader] Controller ready: %s"):format(ctrlName))
end
return Framework
