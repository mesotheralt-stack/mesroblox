local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreatureFactory = require(ReplicatedStorage:WaitForChild("BrainrotShared"):WaitForChild("CreatureFactory"))

local World = {}
local dayCycleStarted = false

local function part(parent, name, size, position, color, material, shape)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.Position = position
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape then object.Shape = shape end
	object.Parent = parent
	return object
end

local function label(adornee, title, subtitle, color, width)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(width or 270, subtitle and 78 or 48)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 220
	gui.AlwaysOnTop = false
	gui.Parent = adornee
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(22, 38, 36)
	frame.BackgroundTransparency = 0.06
	frame.Parent = gui
	local corners = Instance.new("UICorner")
	corners.CornerRadius = UDim.new(0, 12)
	corners.Parent = frame
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -12, subtitle and 0.6 or 1, 0)
	titleLabel.Position = UDim2.fromOffset(6, 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = color or Color3.fromRGB(255, 241, 203)
	titleLabel.Text = title
	titleLabel.Parent = frame
	if subtitle then
		local sub = titleLabel:Clone()
		sub.Size = UDim2.new(1, -12, 0.4, 0)
		sub.Position = UDim2.new(0, 6, 0.6, -3)
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 13
		sub.TextColor3 = Color3.fromRGB(220, 235, 220)
		sub.Text = subtitle
		sub.Parent = frame
	end
end

local function tree(parent, position, scale, color)
	part(parent, "TreeTrunk", Vector3.new(2.4, 10, 2.4) * scale, position + Vector3.new(0, 5 * scale, 0), Color3.fromRGB(110, 76, 47), Enum.Material.Wood)
	part(parent, "TreeCanopy", Vector3.new(13, 13, 13) * scale, position + Vector3.new(0, 13 * scale, 0), color, Enum.Material.Grass, Enum.PartType.Ball)
	part(parent, "TreeCanopy", Vector3.new(10, 10, 10) * scale, position + Vector3.new(4 * scale, 16 * scale, 0), color:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Grass, Enum.PartType.Ball)
end

local function specimenPlaque(parent, position, rarity, species, color, width)
	width = width or 9
	local plaque = part(parent, "SpecimenPlaque", Vector3.new(width, 2.3, 0.3), position, Color3.fromRGB(35, 55, 46), Enum.Material.Wood)
	plaque.CFrame = CFrame.new(position) * CFrame.Angles(0, math.pi, 0)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(width * 55, 150)
	surface.Parent = plaque
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -20, 1, -12)
	text.Position = UDim2.fromOffset(10, 6)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = color
	text.TextSize = 29
	text.TextWrapped = true
	text.Text = rarity .. "\n" .. species
	text.Parent = surface
	return plaque
end

local function prompt(target, action, name, attribute, value)
	local interaction = Instance.new("ProximityPrompt")
	interaction.ActionText = action
	interaction.ObjectText = name
	interaction.HoldDuration = 0
	interaction.KeyboardKeyCode = Enum.KeyCode.F
	interaction.MaxActivationDistance = 15
	interaction.RequiresLineOfSight = false
	interaction:SetAttribute(attribute, value)
	interaction.Parent = target
	return interaction
end

local function shop(parent, name, position, color, subtitle, shopId)
	local wood = Color3.fromRGB(134, 94, 57)
	part(parent, name .. "Platform", Vector3.new(31, 1, 22), position + Vector3.new(0, 0.6, 0), wood, Enum.Material.WoodPlanks)
	for _, x in {-13, 13} do
		for _, z in {-9, 9} do
			part(parent, "ShopPost", Vector3.new(1.2, 12, 1.2), position + Vector3.new(x, 6.5, z), wood, Enum.Material.Wood)
		end
	end
	part(parent, "ShopBack", Vector3.new(28, 7, 0.8), position + Vector3.new(0, 4.6, 9), Color3.fromRGB(238, 223, 183), Enum.Material.WoodPlanks)
	local counter = part(parent, "ShopCounter", Vector3.new(27, 4, 3), position + Vector3.new(0, 3, -6), wood, Enum.Material.WoodPlanks)
	prompt(counter, "Browse", name, "Shop", shopId)
	part(parent, "ShopAwning", Vector3.new(34, 1.4, 25), position + Vector3.new(0, 13, 0), color)
	for x = -14, 14, 7 do
		part(parent, "AwningStripe", Vector3.new(3, 0.08, 25.1), position + Vector3.new(x, 13.75, 0), color:Lerp(Color3.new(1, 1, 1), 0.45))
	end
	local sign = part(parent, "ShopSign", Vector3.new(20, 3, 0.5), position + Vector3.new(0, 11, -11), wood)
	label(sign, name, subtitle, Color3.fromRGB(255, 241, 203))
	-- Counter wares are original geometric props.
	for i = -1, 1 do
		part(parent, "ShopWares", Vector3.new(2.5, 2.5, 2.5), position + Vector3.new(i * 7, 6.2, -5), color:Lerp(Color3.fromRGB(255, 231, 136), (i + 1) * 0.22), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

function World.startDayNight()
	if dayCycleStarted then return end
	dayCycleStarted = true
	Lighting.ClockTime = 9
	Lighting.Brightness = 2.1
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(102, 113, 141)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 151, 164)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Color = Color3.fromRGB(205, 232, 255)
	atmosphere.Decay = Color3.fromRGB(161, 186, 211)
	atmosphere.Parent = Lighting
	task.spawn(function()
		local start = os.clock()
		while true do
			Lighting.ClockTime = (9 + (os.clock() - start) / 30) % 24
			task.wait(0.5)
		end
	end)
end

function World.build(config)
	local old = Workspace:FindFirstChild("BrainrotWorld")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "BrainrotWorld"
	folder.Parent = Workspace
	-- Restricted Workspace settings are serialized by default.project.json.
	local ocean = part(folder, "Ocean", Vector3.new(2200, 3, 900), Vector3.new(520, -12, 0), Color3.fromRGB(70, 168, 195), Enum.Material.Glass)
	ocean.Transparency = 0.2
	ocean.CanCollide = false
	local result = {destinations = {}, pits = {}, displaySlots = {}}
	local ids = {"Meadow", "Dunes", "Cosmic"}
	local names = {"Sprout Meadows", "Amber Dunes", "Starlight Hollow"}
	local colors = {Color3.fromRGB(96, 175, 82), Color3.fromRGB(128, 175, 85), Color3.fromRGB(93, 151, 139)}
	local sandColors = {Color3.fromRGB(239, 215, 157), Color3.fromRGB(236, 183, 101), Color3.fromRGB(178, 159, 221)}
	local rng = Random.new(74119)
	for i, id in ids do
		local offset = Vector3.new((i - 1) * 520, 0, 0)
		local island = Instance.new("Model")
		island.Name = id
		island.Parent = folder
		part(island, "IslandStone", Vector3.new(350, 12, 330), offset + Vector3.new(0, -9, 0), Color3.fromRGB(120, 116, 93), Enum.Material.Slate)
		part(island, "Grass", Vector3.new(350, 6, 330), offset + Vector3.new(0, -2.7, 0), colors[i], Enum.Material.Grass)
		local pitCenter = offset + Vector3.new(0, 0.65, 65)
		local pitSize = Vector3.new(164, 3, 144)
		local digZone = part(island, "DigZone", pitSize, pitCenter - Vector3.new(0, 1.4, 0), sandColors[i], Enum.Material.Sand)
		digZone:SetAttribute("WorldId", id)
		for _, x in {-84, 84} do
			part(island, "PitRim", Vector3.new(3, 1.1, 150), offset + Vector3.new(x, 0.9, 65), Color3.fromRGB(157, 117, 72), Enum.Material.WoodPlanks)
		end
		for _, z in {-9, 139} do
			part(island, "PitRim", Vector3.new(170, 1.1, 3), offset + Vector3.new(0, 0.9, z), Color3.fromRGB(157, 117, 72), Enum.Material.WoodPlanks)
		end
		result.pits[id] = {center = pitCenter, size = pitSize}
		result.destinations[id] = CFrame.new(offset + Vector3.new(0, 5, 7)) * CFrame.Angles(0, math.pi, 0)
		part(island, "MainPath", Vector3.new(17, 0.15, 135), offset + Vector3.new(0, 0.4, -78), Color3.fromRGB(225, 217, 181), Enum.Material.Cobblestone)
		local marker = part(island, "WorldMarker", Vector3.new(1, 8, 1), offset + Vector3.new(0, 5, -25), Color3.fromRGB(120, 85, 48), Enum.Material.Wood)
		local world = config.Worlds and config.Worlds[i]
		if world then names[i] = world.name end
		label(marker, world and world.name or names[i], i == 1 and "Equip your detector and search the sand" or "Unlock this world from the Worlds menu", Color3.fromRGB(255, 235, 166), 340)
		for j = 1, 21 do
			local x = (j % 2 == 0 and -1 or 1) * rng:NextNumber(108, 155)
			local z = rng:NextNumber(-142, 143)
			tree(island, offset + Vector3.new(x, 0, z), rng:NextNumber(0.65, 1.15), colors[i]:Lerp(Color3.fromRGB(32, 100, 53), 0.2))
		end
		for j = 1, 16 do
			local x = rng:NextNumber(-150, 150)
			local z = rng:NextNumber(-143, -112)
			if i == 1 and math.abs(x) < 104 then z = math.max(z, -130) end
			local rock = part(island, "Pebble", Vector3.new(4, 3, 4) * rng:NextNumber(0.4, 1.2), offset + Vector3.new(x, 0.6, z), sandColors[i]:Lerp(Color3.fromRGB(110, 114, 115), 0.5), Enum.Material.Rock, Enum.PartType.Ball)
			rock.Orientation = Vector3.new(0, rng:NextNumber(0, 360), 0)
		end
		-- Tiny glowing lamps keep the sand and pathways readable at night.
		for _, x in {-94, 94} do
			for _, z in {0, 130} do
				part(island, "LampPost", Vector3.new(0.8, 9, 0.8), offset + Vector3.new(x, 4.5, z), Color3.fromRGB(69, 74, 62), Enum.Material.Metal)
				local bulb = part(island, "Lamp", Vector3.new(2.6, 2.6, 2.6), offset + Vector3.new(x, 9.5, z), Color3.fromRGB(255, 228, 158), Enum.Material.Neon, Enum.PartType.Ball)
				local light = Instance.new("PointLight")
				light.Color = bulb.Color
				light.Range = 38
				light.Brightness = 1.6
				light.Parent = bulb
			end
		end
		if i > 1 then
			local portal = part(island, "WorldPortal", Vector3.new(17, 20, 2), offset + Vector3.new(0, 10, -129), sandColors[i], Enum.Material.Neon)
			portal.Transparency = 0.55
			portal.CanCollide = false
			label(portal, names[i], "Access requires the matching world unlock", sandColors[i])
			prompt(portal, "World access", names[i], "WorldId", id)
		end
	end

	shop(folder, "FOOD MARKET", Vector3.new(-64, 0, -66), Color3.fromRGB(241, 139, 95), "Fresh stock every five minutes", "Food")
	shop(folder, "GEAR WORKSHOP", Vector3.new(64, 0, -66), Color3.fromRGB(95, 169, 211), "Detectors and five-minute boosts", "Gear")
	local sell = part(folder, "SellArea", Vector3.new(28, 0.4, 23), Vector3.new(-64, 0.55, -113), Color3.fromRGB(255, 207, 94), Enum.Material.SmoothPlastic)
	label(sell, "SELL BRAINROTS", "Choose a creature in your collection", Color3.fromRGB(255, 219, 109))
	prompt(sell, "Sell", "Sell brainrots", "Shop", "Sell")
	local home = part(folder, "HomePad", Vector3.new(24, 0.5, 20), Vector3.new(0, 0.6, -106), Color3.fromRGB(187, 224, 150))
	label(home, "BRAINROT BLOOM", "Find it. Feed it. Let it flourish.", Color3.fromRGB(192, 240, 139), 340)
	result.spawnCFrame = CFrame.new(0, 5, -91) * CFrame.Angles(0, math.pi, 0)
	result.destinations.Home = result.spawnCFrame
	result.destinations.Food = CFrame.new(-64, 5, -86) * CFrame.Angles(0, math.pi, 0)
	result.destinations.Gear = CFrame.new(64, 5, -86) * CFrame.Angles(0, math.pi, 0)
	result.destinations.Sell = CFrame.new(-64, 5, -113)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GardenSpawn"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 0.85, -91)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
	-- A small rear-grove museum previews the seven rarity tiers. These are
	-- decorative specimens, separate from players' earned companion models.
	local grove = Instance.new("Folder")
	grove.Name = "RarityPreviewGrove"
	grove.Parent = folder
	local heading = specimenPlaque(grove, Vector3.new(0, 7.5, -156), "COLLECTION PREVIEW", "Seven rarities waiting beneath the sand", Color3.fromRGB(218, 236, 180), 19)
	heading.Name = "CollectionPreviewSign"
	for _, x in {-8, 8} do
		part(grove, "PreviewSignPost", Vector3.new(0.7, 7, 0.7), Vector3.new(x, 3.5, -156), Color3.fromRGB(110, 76, 47), Enum.Material.Wood)
	end
	for i, rarity in config.Rarities do
		local specimen
		for _, candidate in config.Creatures do
			if candidate.rarity == rarity.id then specimen = candidate; break end
		end
		if specimen then
			local x, z = (i - 4) * 31, -144
			part(grove, "SpecimenPlinth", Vector3.new(6, 0.8, 6), Vector3.new(x, 0.7, z), Color3.fromRGB(206, 222, 185), Enum.Material.Slate)
			local displayCFrame = CFrame.new(x, 1.2, z) * CFrame.Angles(0, math.pi, 0)
			local model = CreatureFactory.create(specimen, 0.85)
			model.Name = rarity.id .. "Preview"
			model:SetAttribute("DecorativePreview", true)
			model:PivotTo(displayCFrame)
			model.Parent = grove
			specimenPlaque(grove, Vector3.new(x, 1.6, z + 5), rarity.name, specimen.name, rarity.color)
			table.insert(result.displaySlots, displayCFrame)
		end
	end
	World.startDayNight()
	return result
end

return World
