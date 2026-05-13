--!strict
local ConfigCodec = {}

local function enumTypeToName(enumTypeStr: string): string
	-- "Enum.EasingStyle" -> "EasingStyle"
	return (enumTypeStr:match("^Enum%.(.+)$")) or enumTypeStr
end

local function encodeValue(v: any): any
	local tv = typeof(v)

	if tv == "Color3" then
		return { __t = "Color3", hex = (v :: Color3):ToHex() }
	end

	-- EnumItem (e.g. Enum.EasingStyle.Back)
	if tv == "EnumItem" then
		local e = v :: EnumItem
		return {
			__t = "EnumItem",
			enum = tostring(e.EnumType), -- "Enum.EasingStyle"
			name = e.Name,               -- "Back"
		}
	end

	-- Optional: supports Enum.EasingStyle (enum type) if provided.
	if tv == "Enum" then
		return { __t = "EnumType", enum = tostring(v) }
	end

	if tv == "UDim2" then
		local u = v :: UDim2
		return { __t = "UDim2", xs = u.X.Scale, xo = u.X.Offset, ys = u.Y.Scale, yo = u.Y.Offset }
	end

	if tv == "Vector2" then
		local a = v :: Vector2
		return { __t = "Vector2", x = a.X, y = a.Y }
	end

	if tv == "Vector3" then
		local a = v :: Vector3
		return { __t = "Vector3", x = a.X, y = a.Y, z = a.Z }
	end

	if tv == "CFrame" then
		return { __t = "CFrame", components = { (v :: CFrame):GetComponents() } }
	end

	if tv == "table" then
		local out = {}
		for k, val in pairs(v) do
			out[encodeValue(k)] = encodeValue(val)
		end
		return out
	end

	return v
end

local function decodeValue(v: any): any
	if typeof(v) ~= "table" then
		return v
	end

	local tag = rawget(v, "__t")

	if tag == "Color3" then
		return Color3.fromHex(v.hex)
	end

	if tag == "EnumItem" then
		local enumTypeName = enumTypeToName(v.enum)
		local enumType = (Enum :: any)[enumTypeName]
		return enumType and enumType[v.name] or nil
	end

	if tag == "EnumType" then
		local enumTypeName = enumTypeToName(v.enum)
		return (Enum :: any)[enumTypeName]
	end

	if tag == "UDim2" then
		return UDim2.new(v.xs, v.xo, v.ys, v.yo)
	end

	if tag == "Vector2" then
		return Vector2.new(v.x, v.y)
	end

	if tag == "Vector3" then
		return Vector3.new(v.x, v.y, v.z)
	end

	if tag == "CFrame" then
		return CFrame.new(table.unpack(v.components))
	end

	-- regular table
	local out = {}
	for k, val in pairs(v) do
		out[decodeValue(k)] = decodeValue(val)
	end
	return out
end

function ConfigCodec.Encode(t: any): any
	return encodeValue(t)
end

function ConfigCodec.Decode(t: any): any
	return decodeValue(t)
end

return ConfigCodec
