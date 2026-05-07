
local HttpService = game:GetService("HttpService")

local BaseComponent: any = {}
BaseComponent.__index = BaseComponent
BaseComponent.__className = "BaseComponent"

local _framework: any? = nil

-- Weak values so destroyed objects don’t keep memory alive
local ObjectRegistry: { [string]: any } = {} :: { [string]: any }
setmetatable(ObjectRegistry, { __mode = "v" })



local function callChain(obj, methodName: string, ...)
	local methods = {}
	local cur = obj

	while cur do
		local fn = rawget(cur, methodName)
		if type(fn) == "function" then
			table.insert(methods, fn)
		end
		cur = rawget(cur, "super")
	end

	for i = #methods, 1, -1 do
		methods[i](obj, ...)
	end
end

function BaseComponent.SetFramework(framework: any)
	_framework = framework
end

function BaseComponent.GetFramework(): any?
	return _framework
end

function BaseComponent:GetClassName(): string
	local cur: any = self
	while cur do
		local name = rawget(cur, "__className")
		if type(name) == "string" then
			return name
		end
		cur = rawget(cur, "super")
	end
	return "Component"
end

function BaseComponent:GetGuid(): string
	return self.Guid
end

function BaseComponent.EnsureGuid(self)
	if self.Guid == nil then
		self.Guid = HttpService:GenerateGUID(false)
		ObjectRegistry[self.Guid] = self
	end
end

function BaseComponent:EnforceGuid(guid: string)
	if self.Guid ~= nil then
		ObjectRegistry[self.Guid] = nil
	end
	self.Guid = guid
	ObjectRegistry[guid] = self
end

function BaseComponent.GetByGuid(guid: string): any?
	return ObjectRegistry[guid]
end

function BaseComponent:Extend(className: string)
	local subclass: any = {}
	subclass.__index = subclass
	subclass.__className = className
	subclass.super = self
	setmetatable(subclass, self)
	return subclass
end

-- ------------------------------------------------------------------------
-- Internal constructor
--  - runCreate = true  -> behaves like normal "new": calls Create(...)
--  - runCreate = false -> used by Deserialize: skips Create, only sets base fields
-- ------------------------------------------------------------------------
local function construct(classTable: any, runCreate: boolean, ...)
	local framework = BaseComponent.GetFramework()
	if framework == nil then
		error("BaseComponent framework not set. Call BaseComponent.SetFramework(...) before constructing components.")
	end

	local obj: any = {
		_alive = true,
		_cons = {},
		_kids = {},
		Framework = framework,
		super = classTable,
	}

	setmetatable(obj, {
		__index = function(t, k)
			local cur: any = t
			while cur do
				local v = rawget(cur, k)
				if v ~= nil then
					return v
				end
				cur = rawget(cur, "super")
			end
			return nil
		end,
		--__tostring = function(t)
			--return string.format("<%s %s>", t:GetClassName(), t.Guid or "no-guid")
		--end,
	})

	-- Ensure GUID + registry entry exists early
	BaseComponent.EnsureGuid(obj)

	-- Only run Create chain for "real construction"
	if runCreate then
		callChain(obj, "Create", ...)
	end

	return obj
end

function BaseComponent.new(self, ...)
	return construct(self, true, ...)
end

function BaseComponent:AddConnection(conn: RBXScriptConnection)
	if not self._alive then
		conn:Disconnect()
		return
	end
	table.insert(self._cons, conn)
end

function BaseComponent:RemoveConnection(conn: RBXScriptConnection)
	local idx = table.find(self._cons, conn)
	if idx then
		table.remove(self._cons, idx)
		conn:Disconnect()
		return
	end
end

function BaseComponent:AddChild(child: any)
	if not self._alive then
		local ok, destroy = pcall(function()
			return child.Destroy
		end)
		if ok and typeof(destroy) == "function" then
			destroy(child)
		end
		return
	end
	table.insert(self._kids, child)
end

-- Serialization entrypoint
function BaseComponent:Serialize(out: { [string]: any }?): { [string]: any }
	local data = out or {}
	data.Type = data.Type or self:GetClassName()
	data.Guid = self.Guid

	-- Let subclasses add fields
	callChain(self, "OnSerialize", data)

	return data
end

-- Deserialization helper:
-- IMPORTANT: does NOT call Create (so Create(asset, ...) won't run with nil args)
function BaseComponent.Deserialize(classTable: any, data: { [string]: any }): any
	assert(type(data) == "table", "Deserialize expects a table")
	assert(type(data.Guid) == "string", "Deserialize expects data.Guid")
	assert(type(data.Type) == "string", "Deserialize expects data.Type")

	-- Construct WITHOUT Create
	local obj = construct(classTable, false)

	-- Apply GUID from payload
	obj:EnforceGuid(data.Guid)

	-- Let subclasses read fields
	callChain(obj, "OnDeserialize", data)

	return obj
end

function BaseComponent:Destroy()
	if not self._alive then
		return
	end
	self._alive = false

	local className = self:GetClassName()

	-- Allow subclasses/base classes to clean up
	callChain(self, "CleanUp")

	for _, conn in ipairs(self._cons) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	self._cons = {}

	for _, kid in ipairs(self._kids) do
		local ok, destroy = pcall(function()
			return kid.Destroy
		end)
		if ok and typeof(destroy) == "function" then
			destroy(kid)
		end
	end
	self._kids = {}

	-- Remove from registry
	if self.Guid then
		ObjectRegistry[self.Guid] = nil
	end

	if typeof(self.OnDestroy) == "function" then
		self:OnDestroy()
	end

	setmetatable(self, {
		__index = function()
			error(string.format("%s used after Destroy", className), 2)
		end,
		__newindex = function()
			error("Attempt to write to destroyed component", 2)
		end,
		__tostring = function()
			return string.format("<Destroyed %s>", className)
		end,
	})
end

return BaseComponent
