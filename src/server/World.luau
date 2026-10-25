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

-- Signs stay attached to the scenery. No oversized floating destination pins.
local function label(adornee, title, subtitle, color, width)
	local board = adornee
	if adornee.Size.Y < 2 or adornee.Size.X < 4 then
		board = part(adornee.Parent, "WayfindingSign", Vector3.new(math.clamp((width or 250)/22,9,16),3.2,0.35), adornee.Position+Vector3.new(0,adornee.Size.Y/2+1.7,0), Color3.fromRGB(35,52,45),Enum.Material.Wood)
		board.CanCollide = false
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(520,128)
	gui.LightInfluence = 0.25
	gui.MaxDistance = 95
	gui.Parent = board
	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1,-32,subtitle and 0.58 or 1,0)
	heading.Position = UDim2.fromOffset(16,0)
	heading.Font = Enum.Font.BuilderSansBold
	heading.TextSize = 32
	heading.TextColor3 = color or Color3.fromRGB(238,239,221)
	heading.Text = title
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	heading.Parent = gui
	if subtitle then
		local sub = heading:Clone()
		sub.Size = UDim2.new(1,-32,0.42,0)
		sub.Position = UDim2.new(0,16,0.58,-4)
		sub.Font = Enum.Font.BuilderSans
		sub.TextSize = 18
		sub.TextColor3 = Color3.fromRGB(188,206,192)
		sub.Text = subtitle
		sub.Parent = gui
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
	text.Font = Enum.Font.BuilderSansBold
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


local function flower(parent, position, tint, rng)
	local stem = part(parent,"FlowerStem",Vector3.new(0.14,1.1,0.14),position+Vector3.new(0,0.7,0),Color3.fromRGB(72,123,70))
	stem.CanCollide=false
	for i=1,4 do
		local a=i*math.pi/2
		local petal=part(parent,"Petal",Vector3.new(0.58,0.25,0.58),position+Vector3.new(math.cos(a)*0.24,1.3,math.sin(a)*0.24),tint,nil,Enum.PartType.Ball)
		petal.CanCollide=false
	end
end

local function bench(parent, position)
	local wood=Color3.fromRGB(151,115,78)
	part(parent,"BenchSeat",Vector3.new(9,0.45,2.6),position+Vector3.new(0,2,0),wood,Enum.Material.WoodPlanks)
	part(parent,"BenchBack",Vector3.new(9,2,0.4),position+Vector3.new(0,3.0,1.1),wood,Enum.Material.WoodPlanks)
	for _,x in {-3,3} do part(parent,"BenchLeg",Vector3.new(0.5,2,2),position+Vector3.new(x,1,0),Color3.fromRGB(60,73,66),Enum.Material.Metal) end
end

local function scenery(parent, offset, index, rng)
	-- Keep the digging rectangles completely clear. All extra exploration
	-- space lies in the outer woodland and in the garden behind the shops.
	local decor=Instance.new("Folder")
	decor.Name="LandscapeDetails"
	decor.Parent=parent
	local tints={Color3.fromRGB(240,219,151),Color3.fromRGB(255,169,125),Color3.fromRGB(187,178,244)}
	for j=1,20 do
		local side=j%2==0 and -1 or 1
		local position=offset+Vector3.new(side*rng:NextNumber(205,300),0.4,rng:NextNumber(-220,280))
		if index==1 then
			flower(decor,position,tints[index],rng)
		elseif index==2 then
			local cactus=part(decor,"WildCactus",Vector3.new(2.5,6+j%3,2.5),position+Vector3.new(0,3,0),Color3.fromRGB(103,157,106),nil,Enum.PartType.Ball)
			part(decor,"CactusBranch",Vector3.new(3.6,1.1,1.1),cactus.Position+Vector3.new(1.5,0.5,0),cactus.Color)
		else
			local crystal=part(decor,"MoonCrystal",Vector3.new(1.4,4+j%4,1.4),position+Vector3.new(0,2.5,0),tints[index],Enum.Material.Neon)
			crystal.Orientation=Vector3.new(0,j*19,12)
			crystal.Transparency=0.22
		end
	end
	for _,side in {-1,1} do
		bench(decor,offset+Vector3.new(side*125,0.4,-168))
		local hill=part(decor,"WoodlandHill",Vector3.new(58,22,50),offset+Vector3.new(side*285,-6,-244),Color3.fromRGB(99,151,97),Enum.Material.Grass,Enum.PartType.Ball)
		for j=1,5 do
			part(decor,"TrailStone",Vector3.new(5,0.18,4),offset+Vector3.new(side*(23+j*18),0.5,-170),Color3.fromRGB(186,190,160),Enum.Material.Slate)
		end
	end
	if index==1 then
		local shore=part(decor,"PondShore",Vector3.new(72,1,55),offset+Vector3.new(-236,0,-125),Color3.fromRGB(193,188,144),Enum.Material.Sand,Enum.PartType.Ball)
		local water=part(decor,"GardenPond",Vector3.new(63,0.35,46),shore.Position+Vector3.new(0,0.7,0),Color3.fromRGB(99,176,173),Enum.Material.Glass,Enum.PartType.Ball)
		water.Transparency=0.15
		water.CanCollide=false
		for j=1,4 do
			part(decor,"LilyPad",Vector3.new(4,0.15,3.6),water.Position+Vector3.new(j*8-22,0.3,j%2*8-5),Color3.fromRGB(108,155,99),nil,Enum.PartType.Ball)
		end
	else
		for j=-1,1 do
			local color=index==2 and Color3.fromRGB(202,165,117) or Color3.fromRGB(135,137,169)
			part(decor,"AncientPillar",Vector3.new(5,15+math.abs(j)*3,5),offset+Vector3.new(j*17,7,-278),color,Enum.Material.Slate)
		end
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
	local ocean = part(folder, "Ocean", Vector3.new(4000, 3, 1600), Vector3.new(1040, -12, 0), Color3.fromRGB(70, 168, 195), Enum.Material.Glass)
	ocean.Transparency = 0.2
	ocean.CanCollide = false
	local result = {destinations = {}, pits = {}, displaySlots = {}}
	local ids = {"Meadow", "Dunes", "Cosmic"}
	local names = {"Sprout Meadows", "Amber Dunes", "Starlight Hollow"}
	local colors = {Color3.fromRGB(96, 175, 82), Color3.fromRGB(128, 175, 85), Color3.fromRGB(93, 151, 139)}
	local sandColors = {Color3.fromRGB(239, 215, 157), Color3.fromRGB(236, 183, 101), Color3.fromRGB(178, 159, 221)}
	local rng = Random.new(74119)
	for i, id in ids do
		local offset = Vector3.new((i - 1) * 1040, 0, 0)
		local island = Instance.new("Model")
		island.Name = id
		island.Parent = folder
		part(island, "IslandStone", Vector3.new(700, 12, 660), offset + Vector3.new(0, -9, 0), Color3.fromRGB(120, 116, 93), Enum.Material.Slate)
		part(island, "Grass", Vector3.new(700, 6, 660), offset + Vector3.new(0, -2.7, 0), colors[i], Enum.Material.Grass)
		local pitCenter = offset + Vector3.new(0, 0.65, 130)
		local pitSize = Vector3.new(320, 3, 280)
		local digZone = part(island, "DigZone", pitSize, pitCenter - Vector3.new(0, 1.4, 0), sandColors[i], Enum.Material.Sand)
		digZone:SetAttribute("WorldId", id)
		for _, x in {-162, 162} do
			part(island, "PitRim", Vector3.new(3, 1.1, 286), offset + Vector3.new(x, 0.9, 130), Color3.fromRGB(157, 117, 72), Enum.Material.WoodPlanks)
		end
		for _, z in {-12, 272} do
			part(island, "PitRim", Vector3.new(326, 1.1, 3), offset + Vector3.new(0, 0.9, z), Color3.fromRGB(157, 117, 72), Enum.Material.WoodPlanks)
		end
		result.pits[id] = {center = pitCenter, size = pitSize}
		result.destinations[id] = CFrame.new(offset + Vector3.new(0, 5, 7)) * CFrame.Angles(0, math.pi, 0)
		part(island, "MainPath", Vector3.new(17, 0.15, 135), offset + Vector3.new(0, 0.4, -78), Color3.fromRGB(225, 217, 181), Enum.Material.Cobblestone)
		local marker = part(island, "WorldMarker", Vector3.new(1, 8, 1), offset + Vector3.new(0, 5, -25), Color3.fromRGB(120, 85, 48), Enum.Material.Wood)
		local world = config.Worlds and config.Worlds[i]
		if world then names[i] = world.name end
		label(marker, world and world.name or names[i], i == 1 and "Equip your detector and search the sand" or "Unlock this world from the Worlds menu", Color3.fromRGB(255, 235, 166), 340)
		for j = 1, 34 do
			local x = (j % 2 == 0 and -1 or 1) * rng:NextNumber(208, 310)
			local z = rng:NextNumber(-290, 288)
			tree(island, offset + Vector3.new(x, 0, z), rng:NextNumber(0.65, 1.15), colors[i]:Lerp(Color3.fromRGB(32, 100, 53), 0.2))
		end
		for j = 1, 16 do
			local x = rng:NextNumber(-305, 305)
			local z = rng:NextNumber(-295, -230)
			if i == 1 and math.abs(x) < 104 then x += 130 end
			local rock = part(island, "Pebble", Vector3.new(4, 3, 4) * rng:NextNumber(0.4, 1.2), offset + Vector3.new(x, 0.6, z), sandColors[i]:Lerp(Color3.fromRGB(110, 114, 115), 0.5), Enum.Material.Rock, Enum.PartType.Ball)
			rock.Orientation = Vector3.new(0, rng:NextNumber(0, 360), 0)
		end
		scenery(island, offset, i, rng)
		-- Tiny glowing lamps keep the sand and pathways readable at night.
		for _, x in {-175, 175} do
			for _, z in {0, 130, 260} do
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
			local portal = part(island, "WorldPortal", Vector3.new(17, 20, 2), offset + Vector3.new(0, 10, -210), sandColors[i], Enum.Material.Neon)
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
	local heading = specimenPlaque(grove, Vector3.new(0, 7.5, -242), "COLLECTION PREVIEW", "Seven rarities waiting beneath the sand", Color3.fromRGB(218, 236, 180), 19)
	heading.Name = "CollectionPreviewSign"
	for _, x in {-8, 8} do
		part(grove, "PreviewSignPost", Vector3.new(0.7, 7, 0.7), Vector3.new(x, 3.5, -242), Color3.fromRGB(110, 76, 47), Enum.Material.Wood)
	end
	for i, rarity in config.Rarities do
		local specimen
		for _, candidate in config.Creatures do
			if candidate.rarity == rarity.id then specimen = candidate; break end
		end
		if specimen then
			local x, z = (i - 4) * 31, -222
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
