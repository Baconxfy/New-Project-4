local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BrainrotBillboard = {}

local BRAINROTS_FOLDER = ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Brainrots')
local BILLBOARD_TEMPLATES = BRAINROTS_FOLDER:WaitForChild('BillboardGuis')

local DEFAULT_MUTATION = 'Normal'
local DEFAULT_RARITY = 'Common'
local DEFAULT_SIZE = UDim2.fromOffset(260, 130)
local DEFAULT_MAX_DISTANCE = 120
local DEFAULT_TOP_PADDING = 0.65
local DEFAULT_MUTATION_TOP_PADDING = 0.75
local ROLLING_HIGHLIGHT_NAME = 'Rolling Anim Highlight'

local function setRollingHighlights(model: Model, enabled: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('Highlight') and descendant.Name == ROLLING_HIGHLIGHT_NAME then
			descendant.Adornee = if enabled then model else nil
			descendant.Enabled = enabled
		end
	end
end

local function getRootPart(model: Model): BasePart?
	local centerCube = model:FindFirstChild('CenterCube', true)
	if centerCube and centerCube:IsA('BasePart') then
		return centerCube
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart', true)
end

local function getTemplateName(rarity: string?): string
	local normalized = tostring(rarity or DEFAULT_RARITY)
	if normalized == DEFAULT_RARITY then
		return 'BrainrotNormal'
	end
	return 'Brainrot' .. normalized
end

local function hasTextLabels(instance: Instance): boolean
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA('TextLabel') then
			return true
		end
	end
	return false
end

local function findTemplate(rarity: string?): Instance?
	local templateName = getTemplateName(rarity)
	local fallback: Instance? = nil

	for _, child in ipairs(BILLBOARD_TEMPLATES:GetChildren()) do
		if child.Name == templateName then
			if child:IsA('BillboardGui') and hasTextLabels(child) then
				return child
			end
			if child:IsA('Folder') and hasTextLabels(child) and not fallback then
				fallback = child
			elseif child:IsA('BillboardGui') and not fallback then
				fallback = child
			end
		end
	end

	if rarity ~= DEFAULT_RARITY then
		return findTemplate(DEFAULT_RARITY)
	end
	return fallback
end

local function createBillboard(template: Instance): BillboardGui?
	if template:IsA('BillboardGui') then
		return template:Clone()
	end

	if template:IsA('Folder') then
		local billboard = Instance.new('BillboardGui')
		billboard.Name = template.Name
		for _, child in ipairs(template:GetChildren()) do
			local clone = child:Clone()
			clone.Parent = billboard
		end
		return billboard
	end

	return nil
end

local function getSections(root: Instance, sectionName: string)
	local sections = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == sectionName and (descendant:IsA('GuiObject') or descendant:IsA('Folder')) then
			table.insert(sections, descendant)
		end
	end
	return sections
end

local function setSectionText(root: Instance, sectionName: string, text: string)
	for _, section in ipairs(getSections(root, sectionName)) do
		if section:IsA('TextLabel') then
			section.Text = text
		end
		for _, descendant in ipairs(section:GetDescendants()) do
			if descendant:IsA('TextLabel') then
				descendant.Text = text
			end
		end
	end
end

local function setSectionVisible(root: Instance, sectionName: string, visible: boolean)
	for _, section in ipairs(getSections(root, sectionName)) do
		if section:IsA('GuiObject') then
			section.Visible = visible
		end
	end
end

local function formatNumber(value: number): string
	local absValue = math.abs(value)
	if absValue >= 1000000000 then
		return ('%.2fB'):format(value / 1000000000):gsub('%.?0+B$', 'B')
	elseif absValue >= 1000000 then
		return ('%.2fM'):format(value / 1000000):gsub('%.?0+M$', 'M')
	elseif absValue >= 1000 then
		return ('%.2fK'):format(value / 1000):gsub('%.?0+K$', 'K')
	elseif value % 1 == 0 then
		return tostring(math.floor(value))
	end
	return ('%.2f'):format(value):gsub('0+$', ''):gsub('%.$', '')
end

local function getConfig(framework, brainrotName: string?, modelName: string?)
	local configs = framework and framework.Config and framework.Config.Brainrots
	if type(configs) ~= 'table' then
		return {}
	end
	return configs[tostring(brainrotName or '')] or configs[tostring(modelName or '')] or {}
end

local function getMutationConfig(framework, mutationName: string)
	local mutations = framework and framework.Config and framework.Config.Mutations and framework.Config.Mutations.Mutations
	if type(mutations) ~= 'table' then
		return {}
	end
	return mutations[mutationName] or {}
end

function BrainrotBillboard.Attach(model: Model, framework, info)
	local rootPart = getRootPart(model)
	if not rootPart then
		return nil
	end

	setRollingHighlights(model, false)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('BillboardGui') and descendant.Name == 'BrainrotBillboardGui' then
			descendant:Destroy()
		end
	end

	local displayName = tostring(info and info.Name or model.Name)
	local modelName = tostring(info and info.ModelName or model.Name)
	local config = getConfig(framework, displayName, modelName)
	local rarity = tostring((info and info.Rarity) or model:GetAttribute('Rarity') or config.Rarity or DEFAULT_RARITY)
	local mutation = tostring((info and info.Mutation) or model:GetAttribute('Mutation') or config.Mutation or DEFAULT_MUTATION)
	local mutationConfig = getMutationConfig(framework, mutation)
	local mutationDisplayName = tostring(mutationConfig.DisplayName or mutation)
	local isMutation = if type(mutationConfig.IsMutation) == 'boolean' then mutationConfig.IsMutation else mutation ~= DEFAULT_MUTATION
	local income = tonumber(info and info.BaseIncome)
		or tonumber(model:GetAttribute('MoneyPerSecond'))
		or tonumber(model:GetAttribute('BaseIncome'))
		or tonumber(config.MoneyPerSecond)
		or tonumber(config.BaseIncome)
		or 0

	local template = findTemplate(rarity)
	if not template then
		return nil
	end

	local billboard = createBillboard(template)
	if not billboard then
		return nil
	end

	local boundingBoxCFrame, size = model:GetBoundingBox()
	local mutationPadding = if isMutation then DEFAULT_MUTATION_TOP_PADDING else 0
	local topPosition = boundingBoxCFrame.Position + Vector3.new(0, size.Y * 0.5 + DEFAULT_TOP_PADDING + mutationPadding, 0)
	local offset = topPosition - rootPart.Position + Vector3.new(0, 2, 0)

	billboard.Name = 'BrainrotBillboardGui'
	billboard.Adornee = rootPart
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	if billboard.Size == UDim2.new() then
		billboard.Size = DEFAULT_SIZE
	end
	if billboard.MaxDistance == 0 then
		billboard.MaxDistance = DEFAULT_MAX_DISTANCE
	end
	billboard.StudsOffsetWorldSpace = offset

	setSectionText(billboard, 'Name', displayName)
	setSectionText(billboard, 'Rarity', rarity)
	setSectionVisible(billboard, 'Mutation', isMutation)
	if isMutation then
		setSectionText(billboard, 'Mutation', mutationDisplayName)
	end
	setSectionText(billboard, 'Cash', '$' .. formatNumber(income) .. '/s')

	billboard.Parent = rootPart
	return billboard
end

return BrainrotBillboard
