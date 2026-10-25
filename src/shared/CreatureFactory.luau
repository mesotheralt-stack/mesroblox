-- Original, dependency-free toy creatures. Every piece is anchored for use in
-- world displays and ViewportFrames; callers move the result with PivotTo.
local CreatureFactory = {}

local function piece(model, name, size, position, color, shape, rotation)
	local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position) * (rotation or CFrame.new())
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape and shape ~= "Wedge" then part.Shape = shape end
	part.Parent = model
	return part
end

function CreatureFactory.create(spec, scale)
	local model = Instance.new("Model")
	model.Name = spec.name or "Brainrot"
	local color = spec.color or Color3.fromRGB(158, 225, 110)
	local accent = spec.accent or Color3.fromRGB(255, 210, 91)
	local white = Color3.fromRGB(255, 253, 242)
	local ink = Color3.fromRGB(28, 38, 42)
	local shape = string.lower(spec.shape or "blob")
	local root = piece(model, "Root", Vector3.new(0.2, 0.2, 0.2), Vector3.zero, color)
	root.Transparency = 1
	model.PrimaryPart = root
	local proportions = {
		toast = Vector3.new(2.65, 2.9, 1.6), rock = Vector3.new(2.9, 2.65, 2.4),
		frog = Vector3.new(3.15, 2.7, 2.5), bee = Vector3.new(2.6, 2.9, 2.5),
		shark = Vector3.new(2.7, 3.2, 2.7), cactus = Vector3.new(2.3, 3.35, 2.0),
		octopus = Vector3.new(3.1, 2.85, 2.5), bird = Vector3.new(2.5, 3.0, 2.4),
		dragon = Vector3.new(2.7, 3.25, 2.5), capybara = Vector3.new(3.0, 2.8, 2.7),
	}
	piece(model, "Body", proportions[shape] or Vector3.new(2.8, 3.1, 2.2), Vector3.new(0, 2.3, 0), color, Enum.PartType.Ball)
	piece(model, "BellyPatch", Vector3.new(1.55, 1.3, 0.22), Vector3.new(0, 1.58, -0.96), color:Lerp(white, 0.36), Enum.PartType.Ball)
	piece(model, "LeftFoot", Vector3.new(0.95, 0.55, 1.4), Vector3.new(-0.75, 0.45, -0.3), accent, Enum.PartType.Ball)
	piece(model, "RightFoot", Vector3.new(0.95, 0.55, 1.4), Vector3.new(0.75, 0.45, -0.3), accent, Enum.PartType.Ball)
	for _, side in {-1, 1} do
		local x = side * 0.62
		piece(model, "EyeWhite", Vector3.new(0.88, 1.05, 0.4), Vector3.new(x, 2.9, -1.02), white, Enum.PartType.Ball)
		piece(model, "Pupil", Vector3.new(0.38, 0.54, 0.18), Vector3.new(x + 0.06, 2.9, -1.24), ink, Enum.PartType.Ball)
		piece(model, "Glint", Vector3.new(0.12, 0.16, 0.08), Vector3.new(x - 0.02, 3.05, -1.34), white, Enum.PartType.Ball)
		piece(model, "Cheek", Vector3.new(0.45, 0.22, 0.15), Vector3.new(side * 0.99, 2.34, -0.93), Color3.fromRGB(255, 151, 143), Enum.PartType.Ball)
		piece(model, "Arm", Vector3.new(0.55, 1.3, 0.6), Vector3.new(side * 1.35, 2.0, 0), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, side * 0.5))
	end
	piece(model, "Smile", Vector3.new(0.65, 0.14, 0.18), Vector3.new(0, 2.13, -1.08), ink, Enum.PartType.Ball)

	-- Familiar silhouettes with silly original combinations; unrecognised shape
	-- names still produce a complete creature with a tuft.
	if string.find(shape, "toast") or string.find(shape, "bread") then
		piece(model, "ToastCrust", Vector3.new(3.0, 2.9, 0.8), Vector3.new(0, 2.5, 0.65), accent)
		piece(model, "ToastCenter", Vector3.new(2.5, 2.4, 0.12), Vector3.new(0, 2.55, -0.05), color)
	elseif string.find(shape, "mush") then
		piece(model, "MushroomCap", Vector3.new(4.0, 1.4, 3.4), Vector3.new(0, 3.9, 0), accent, Enum.PartType.Ball)
		for i = 1, 5 do
			local angle = i * math.pi * 2 / 5
			piece(model, "CapSpot", Vector3.new(0.5, 0.16, 0.5), Vector3.new(math.cos(angle) * 1.1, 4.45, math.sin(angle) * 0.8), white, Enum.PartType.Ball)
		end
	elseif string.find(shape, "cat") or string.find(shape, "bunny") then
		for _, side in {-1, 1} do
			piece(model, "Ear", Vector3.new(0.72, string.find(shape, "bunny") and 2.1 or 1.25, 0.7), Vector3.new(side * 0.9, 4.0, 0), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, side * -0.2))
		end
	elseif string.find(shape, "crown") or string.find(shape, "king") then
		piece(model, "CrownBand", Vector3.new(2.4, 0.45, 2.0), Vector3.new(0, 3.9, 0), accent)
		for i = -1, 1 do
			piece(model, "CrownPoint", Vector3.new(0.45, 0.9, 0.45), Vector3.new(i * 0.8, 4.45, 0), accent)
		end
	elseif string.find(shape, "planet") or string.find(shape, "cosmic") then
		local ring = piece(model, "Orbit", Vector3.new(0.18, 5.0, 5.0), Vector3.new(0, 2.5, 0), accent, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(65)))
		ring.Transparency = 0.32
		ring.Material = Enum.Material.Neon
	elseif string.find(shape, "cactus") then
		for i = 1, 6 do
			local angle = i * math.pi / 3
			piece(model, "Spine", Vector3.new(0.16, 0.65, 0.16), Vector3.new(math.cos(angle) * 1.2, 3.3, math.sin(angle)), white, nil, CFrame.Angles(0, 0, angle))
		end
	elseif string.find(shape, "coffee") or string.find(shape, "cup") then
		piece(model, "CupRim", Vector3.new(0.25, 2.7, 2.7), Vector3.new(0, 3.7, 0), accent, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
		piece(model, "Coffee", Vector3.new(0.28, 2.25, 2.25), Vector3.new(0, 3.85, 0), Color3.fromRGB(92, 49, 33), Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
		piece(model, "Handle", Vector3.new(1.0, 1.6, 0.7), Vector3.new(1.65, 2.65, 0), accent, Enum.PartType.Ball)
	elseif shape == "sprout" then
		piece(model, "Stem", Vector3.new(0.22, 1.4, 0.22), Vector3.new(0, 4.0, 0), accent)
		for _, side in {-1, 1} do
			piece(model, "Leaf", Vector3.new(1.4, 0.4, 0.8), Vector3.new(side * 0.6, 4.5, 0), color, Enum.PartType.Ball, CFrame.Angles(0, 0, side * 0.4))
		end
	elseif shape == "rock" then
		for i = 1, 5 do
			local angle = i * math.pi * 2 / 5
			piece(model, "PebbleCrest", Vector3.new(0.7, 0.6, 0.7), Vector3.new(math.cos(angle) * 0.65, 3.65, math.sin(angle) * 0.5), accent, Enum.PartType.Ball)
		end
	elseif shape == "frog" then
		for _, side in {-1, 1} do
			piece(model, "FrogEyeStalk", Vector3.new(1.0, 1.0, 0.9), Vector3.new(side * 0.83, 3.65, -0.2), color, Enum.PartType.Ball)
			piece(model, "FrogSpot", Vector3.new(0.4, 0.15, 0.5), Vector3.new(side * 0.95, 3.92, -0.45), accent, Enum.PartType.Ball)
		end
	elseif shape == "bee" then
		for _, side in {-1, 1} do
			local wing = piece(model, "Wing", Vector3.new(1.9, 2.8, 0.25), Vector3.new(side * 1.5, 3.1, 0.7), white, Enum.PartType.Ball, CFrame.Angles(0, 0, side * -0.6))
			wing.Transparency = 0.3
			piece(model, "Antenna", Vector3.new(0.15, 1.1, 0.15), Vector3.new(side * 0.7, 4.1, 0), accent, nil, CFrame.Angles(0, 0, side * -0.3))
			piece(model, "AntennaTip", Vector3.new(0.4, 0.4, 0.4), Vector3.new(side * 0.85, 4.6, 0), accent, Enum.PartType.Ball)
		end
		piece(model, "BeeStripe", Vector3.new(2.7, 0.35, 0.3), Vector3.new(0, 1.7, -0.8), accent)
	elseif shape == "shark" then
		piece(model, "DorsalFin", Vector3.new(0.45, 1.7, 1.2), Vector3.new(0, 4.0, 0.4), accent, nil, CFrame.Angles(math.rad(-25), 0, 0))
		piece(model, "SharkTail", Vector3.new(0.7, 2.3, 0.5), Vector3.new(0, 2.4, 1.7), color, nil, CFrame.Angles(0, 0, math.rad(35)))
		for _, side in {-1, 1} do
			piece(model, "SideFin", Vector3.new(1.5, 0.35, 1.0), Vector3.new(side * 1.65, 2.5, 0.1), color, nil, CFrame.Angles(0, 0, side * -0.3))
		end
	elseif shape == "cloud" then
		for i = -1, 1 do
			piece(model, "CloudPuff", Vector3.new(1.7, 1.6, 1.7), Vector3.new(i * 0.85, 3.8 + (1 - math.abs(i)) * 0.3, 0), white, Enum.PartType.Ball)
		end
	elseif shape == "octopus" or shape == "jelly" then
		for i = 1, 8 do
			local angle = i * math.pi / 4
			piece(model, "Tentacle", Vector3.new(0.6, 0.8, 1.7), Vector3.new(math.sin(angle) * 1.1, 0.65, math.cos(angle) * 0.9), accent, Enum.PartType.Ball, CFrame.Angles(0, angle, 0))
		end
		if shape == "jelly" then
			local dome = piece(model, "SpaceHelmet", Vector3.new(3.6, 3.8, 3.0), Vector3.new(0, 2.7, 0), white, Enum.PartType.Ball)
			dome.Transparency = 0.8
		end
	elseif shape == "bird" or shape == "phoenix" or shape == "dragon" then
		for _, side in {-1, 1} do
			for feather = 1, 3 do
				piece(model, "WingFeather", Vector3.new(0.6, 2.6 - feather * 0.3, 0.65), Vector3.new(side * (1.3 + feather * 0.35), 2.65, 0.2), feather % 2 == 0 and color or accent, Enum.PartType.Ball, CFrame.Angles(0, 0, side * -0.65))
			end
		end
		piece(model, "Beak", Vector3.new(0.65, 0.55, 0.7), Vector3.new(0, 2.4, -1.2), accent, Enum.PartType.Ball)
		if shape == "dragon" then
			for _, side in {-1, 1} do
				piece(model, "DragonHorn", Vector3.new(0.45, 1.5, 0.45), Vector3.new(side * 0.8, 4.0, 0), white, nil, CFrame.Angles(0, 0, side * -0.3))
			end
			piece(model, "DragonTail", Vector3.new(0.7, 0.8, 2.7), Vector3.new(0, 1.3, 1.7), color, Enum.PartType.Ball)
		elseif shape == "phoenix" then
			for i = -1, 1 do
				local flame = piece(model, "FlameCrest", Vector3.new(0.45, 1.7 - math.abs(i) * 0.3, 0.5), Vector3.new(i * 0.55, 4.1, 0), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, i * -0.2))
				flame.Material = Enum.Material.Neon
			end
			piece(model, "PhoenixTail", Vector3.new(1.5, 0.5, 2.5), Vector3.new(0, 1.8, 1.5), accent, Enum.PartType.Ball)
		else
			for i = -1, 1 do
				piece(model, "DiscoCrest", Vector3.new(0.45, 1.2, 0.45), Vector3.new(i * 0.45, 4.0, 0), accent, Enum.PartType.Ball)
			end
		end
	elseif shape == "wizard" then
		piece(model, "HatBrim", Vector3.new(0.2, 3.5, 3.5), Vector3.new(0, 3.8, 0), accent, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
		piece(model, "WizardHat", Vector3.new(1.7, 1.8, 1.7), Vector3.new(0, 4.5, 0), color)
		piece(model, "HatTip", Vector3.new(0.8, 1.1, 0.8), Vector3.new(0.3, 5.7, 0), accent, nil, CFrame.Angles(0, 0, -0.3))
	elseif shape == "sun" or shape == "lion" then
		for i = 1, 12 do
			local angle = i * math.pi / 6
			piece(model, "ManeRay", Vector3.new(0.6, 1.3, 0.5), Vector3.new(math.sin(angle) * 1.8, 2.6 + math.cos(angle) * 1.8, 0.3), accent, shape == "lion" and Enum.PartType.Ball or nil, CFrame.Angles(0, 0, -angle))
		end
	elseif shape == "moon" or shape == "void" then
		for i = 1, 5 do
			local angle = i * math.pi * 2 / 5
			local star = piece(model, "OrbitStar", Vector3.new(0.45, 0.45, 0.45), Vector3.new(math.cos(angle) * 2.2, 3.1 + math.sin(angle) * 1.6, 0), accent, nil, CFrame.Angles(0, 0, math.pi / 4))
			star.Material = Enum.Material.Neon
		end
		if shape == "void" then
			for i = 1, 20 do
				local a, b = i * math.pi / 10, (i + 1) * math.pi / 10
				local p = Vector3.new(math.cos(a) * 2.35, 2.65 + math.sin(a) * 1.1, math.sin(a) * 1.9)
				local q = Vector3.new(math.cos(b) * 2.35, 2.65 + math.sin(b) * 1.1, math.sin(b) * 1.9)
				local ring = piece(model, "VoidHalo", Vector3.new(0.12, 0.12, (q - p).Magnitude + 0.05), (p + q) / 2, accent, nil, CFrame.lookAt(Vector3.zero, q - p))
				ring.Material = Enum.Material.Neon
			end
		else
			for i = 0, 7 do
				local a = -1.1 + i * 0.32
				piece(model, "MoonCrescent", Vector3.new(0.65, 0.65, 0.5), Vector3.new(1.1 + math.cos(a) * 1.2, 3.1 + math.sin(a) * 1.2, 0.3), accent, Enum.PartType.Ball)
			end
		end
	elseif shape == "capybara" then
		for _, side in {-1, 1} do
			piece(model, "RoundEar", Vector3.new(0.8, 0.9, 0.6), Vector3.new(side * 1.0, 3.65, 0), accent, Enum.PartType.Ball)
		end
		piece(model, "Snout", Vector3.new(1.2, 0.75, 0.5), Vector3.new(0, 2.0, -1.08), accent, Enum.PartType.Ball)
		piece(model, "Nose", Vector3.new(0.4, 0.2, 0.16), Vector3.new(0, 2.25, -1.38), ink, Enum.PartType.Ball)
	else
		for i = -1, 1 do
			piece(model, "SillyTuft", Vector3.new(0.55, 1.05 - math.abs(i) * 0.2, 0.55), Vector3.new(i * 0.55, 3.9, 0), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, i * -0.35))
		end
	end
	-- Small, deliberately placed details give each collectible a toy-like finish.
	-- Keep the geometry bounded: no textures, emitters, scripts, or downloaded models.
	local pale = accent:Lerp(white, 0.45)
	local shade = color:Lerp(ink, 0.22)
	local function dot(name, position, size, tint)
		return piece(model, name, Vector3.new(size, size, size), position, tint or pale, Enum.PartType.Ball)
	end
	local function rod(name, a, b, width, tint)
		return piece(model, name, Vector3.new(width, width, (b-a).Magnitude), (a+b)/2, tint or accent, nil, CFrame.lookAt(Vector3.zero, b-a))
	end
	local function orbit(name, center, radius, tint, count)
		for i = 1, count or 12 do
			local a = (i-1) * math.pi*2/(count or 12)
			local b = i * math.pi*2/(count or 12)
			rod(name, center+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius), center+Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius), 0.12, tint)
		end
	end
	for _, side in {-1, 1} do
		piece(model, "Eyebrow", Vector3.new(0.65, 0.12, 0.14), Vector3.new(side*0.62,3.5,-0.97), shade, Enum.PartType.Ball, CFrame.Angles(0,0,side*-0.12))
		dot("TinyEyeGlint", Vector3.new(side*0.62+0.16,2.77,-1.35),0.09,white)
		for toe = 1, 2 do
			piece(model, "ToeSeam", Vector3.new(0.045,0.07,0.32),Vector3.new(side*0.75+(toe-1.5)*0.21,0.64,-0.8),accent:Lerp(ink,0.22))
		end
	end
	if shape == "toast" then
		for i = 1, 7 do
			local x = ((i*7)%11-5)*0.19
			dot("ToastedFreckle",Vector3.new(x,1.6+(i%3)*0.5,-0.89),0.13,shade)
		end
		piece(model,"ButterPat",Vector3.new(0.75,0.15,0.7),Vector3.new(0.2,3.9,0),Color3.fromRGB(255,231,132),nil,CFrame.Angles(0,0.2,0.1))
	elseif shape == "sprout" then
		piece(model,"PastaScarf",Vector3.new(2.1,0.25,1.7),Vector3.new(0,1.1,0),accent,Enum.PartType.Ball)
		for i=1,3 do
			rod("NoodleStrand",Vector3.new(0.75+i*0.12,1.2,-0.45),Vector3.new(0.75+i*0.12,0.65,-0.65),0.12,accent)
		end
		for _,side in {-1,1} do
			rod("LeafVein",Vector3.new(side*0.13,4.55,-0.05),Vector3.new(side*1.06,4.7,-0.05),0.06,pale)
		end
	elseif shape == "rock" then
		for i=1,5 do
			dot("MineralFleck",Vector3.new(-1.0+(i%3)*0.28,1.4+math.floor(i/3)*0.26,-0.98),0.17,pale)
		end
		rod("StoneCrack",Vector3.new(0.7,3.65,-0.45),Vector3.new(0.94,3.32,-0.85),0.07,shade)
		rod("StoneCrack",Vector3.new(0.94,3.32,-0.85),Vector3.new(1.15,3.22,-0.7),0.07,shade)
	elseif shape == "frog" then
		for _,side in {-1,1} do
			piece(model,"Haunch",Vector3.new(1.15,1.0,1.25),Vector3.new(side*1.27,1.05,0.35),shade,Enum.PartType.Ball)
			for i=1,3 do dot("WebbedToe",Vector3.new(side*1.35+(i-2)*0.22,0.35,-0.3),0.3,accent) end
			dot("FrogEye",Vector3.new(side*0.83,3.79,-0.64),0.48,white)
			dot("FrogPupil",Vector3.new(side*0.83,3.79,-0.86),0.24,ink)
		end
	elseif shape == "mushroom" then
		for i=1,9 do
			local a=i*math.pi*2/9
			rod("CapGills",Vector3.new(math.cos(a)*0.55,3.65,math.sin(a)*0.4),Vector3.new(math.cos(a)*1.65,3.65,math.sin(a)*1.25),0.065,pale)
		end
		piece(model,"MushroomCollar",Vector3.new(2.3,0.24,1.8),Vector3.new(0,1.1,0),white,Enum.PartType.Ball)
	elseif shape == "bee" then
		for i=1,3 do
			piece(model,"BackStripe",Vector3.new(2.1,0.18,0.35),Vector3.new(0,1.65+i*0.45,1.0),accent,Enum.PartType.Ball)
		end
		for _,side in {-1,1} do
			rod("WingVein",Vector3.new(side*1.2,2.6,0.55),Vector3.new(side*2.0,4.0,0.55),0.06,pale)
		end
		piece(model,"Stinger",Vector3.new(0.45,0.7,0.65),Vector3.new(0,1.0,1.2),accent,"Wedge")
	elseif shape == "shark" then
		for _,side in {-1,1} do
			for i=1,3 do rod("Gill",Vector3.new(side*1.1,2.0+i*0.22,-0.7),Vector3.new(side*1.3,1.88+i*0.22,-0.25),0.065,shade) end
			piece(model,"SlipperSole",Vector3.new(1.1,0.15,1.8),Vector3.new(side*0.75,0.22,-0.35),white,Enum.PartType.Ball)
		end
		for i=-1,1 do piece(model,"SharkTooth",Vector3.new(0.14,0.23,0.1),Vector3.new(i*0.18,2.01,-1.19),white,"Wedge") end
	elseif shape == "cactus" then
		for _,side in {-1,1} do
			piece(model,"CactusBranch",Vector3.new(0.65,1.6,0.65),Vector3.new(side*1.5,2.6,0),color,Enum.PartType.Ball)
			for i=1,4 do dot("SpineBud",Vector3.new(side*0.9,1.35+i*0.43,-0.67),0.11,white) end
		end
		for i=1,5 do local a=i*math.pi*2/5; dot("FlowerPetal",Vector3.new(math.cos(a)*0.38,4.0,math.sin(a)*0.38),0.53,accent) end
		dot("FlowerCenter",Vector3.new(0,4.18,0),0.35,Color3.fromRGB(255,220,128))
	elseif shape == "cloud" then
		for i=1,5 do
			dot("CloudCurl",Vector3.new(-1.4+i*0.45,1.05,0.55),0.65,white)
		end
		for _,side in {-1,1} do
			rod("RaindropTrail",Vector3.new(side*1.65,1.9,0),Vector3.new(side*1.65,1.4,0),0.08,accent)
			dot("Raindrop",Vector3.new(side*1.65,1.25,0),0.28,accent)
		end
	elseif shape == "octopus" or shape == "jelly" then
		for i=1,8 do
			local a=i*math.pi/4
			for j=1,2 do dot("SuctionCup",Vector3.new(math.sin(a)*(1.1+j*0.21),0.41,math.cos(a)*(1+j*0.21)),0.2,pale) end
		end
		if shape == "jelly" then
			orbit("HelmetSeal",Vector3.new(0,1.05,0),1.43,white,12)
			piece(model,"OxygenPack",Vector3.new(1.35,1.45,0.65),Vector3.new(0,2.3,1.3),accent)
			dot("SuitBadge",Vector3.new(0,1.55,-1.12),0.4,accent)
		else
			for i=1,4 do dot("HeadFreckle",Vector3.new(-0.7+i*0.28,3.52,-0.55),0.16,pale) end
		end
	elseif shape == "bird" or shape == "phoenix" or shape == "dragon" then
		for _,side in {-1,1} do
			for i=1,3 do
				rod("FeatherVein",Vector3.new(side*(1.3+i*0.35),2.2,0.0),Vector3.new(side*(1.6+i*0.35),3.1,0.0),0.065,pale)
			end
		end
		if shape == "dragon" then
			for i=1,5 do
				piece(model,"SpineScale",Vector3.new(0.42,0.6,0.55),Vector3.new(0,3.6-i*0.33,0.9+i*0.22),accent,"Wedge")
			end
			for _,side in {-1,1} do dot("Nostril",Vector3.new(side*0.23,2.52,-1.5),0.13,ink) end
		elseif shape == "phoenix" then
			for i=-1,1 do
				piece(model,"LongTailPlume",Vector3.new(0.38,0.3,2.6-math.abs(i)*0.3),Vector3.new(i*0.42,1.5,2.0),i==0 and color or accent,Enum.PartType.Ball,CFrame.Angles(0,i*0.22,0))
			end
		else
			piece(model,"DiscoVisor",Vector3.new(1.9,0.18,0.2),Vector3.new(0,3.22,-1.13),accent)
			for i=-1,1 do dot("DiscoSequin",Vector3.new(i*0.45,1.6,-1.11),0.19,pale) end
		end
	elseif shape == "wizard" then
		orbit("HatRibbon",Vector3.new(0,4.1,0),0.98,accent,10)
		for i=1,3 do
			piece(model,"HatRune",Vector3.new(0.18,0.18,0.08),Vector3.new((i-2)*0.4,4.6+(i%2)*0.35,-0.89),pale,nil,CFrame.Angles(0,0,math.pi/4))
		end
		rod("MagicWand",Vector3.new(1.55,1.3,-0.1),Vector3.new(1.95,3.4,-0.1),0.15,shade)
		dot("WandGem",Vector3.new(1.95,3.5,-0.1),0.44,accent)
	elseif shape == "lion" then
		for _,side in {-1,1} do
			piece(model,"Muzzle",Vector3.new(0.63,0.53,0.3),Vector3.new(side*0.27,2.05,-1.05),pale,Enum.PartType.Ball)
			for i=1,2 do rod("Whisker",Vector3.new(side*0.65,2.0,-1.1),Vector3.new(side*1.15,2.1+(i-1)*0.15,-1.02),0.035,ink) end
		end
		dot("LionNose",Vector3.new(0,2.24,-1.27),0.26,shade)
	elseif shape == "sun" then
		orbit("SunCrown",Vector3.new(0,3.85,0),0.8,pale,10)
		for i=1,6 do
			local a=i*math.pi/3
			dot("SunSpark",Vector3.new(math.sin(a)*2.12,2.6+math.cos(a)*2.12,0.3),0.24,pale)
		end
	elseif shape == "moon" then
		for i=1,4 do
			dot("MoonCrater",Vector3.new(-1.0+(i%2)*0.28,1.4+math.floor(i/2)*0.43,-0.85),0.23,shade)
		end
		piece(model,"MochiWrap",Vector3.new(2.4,0.45,2.0),Vector3.new(0,0.9,0),accent,Enum.PartType.Ball)
	elseif shape == "void" then
		for i=1,4 do
			local glyph=piece(model,"VoidGlyph",Vector3.new(0.18,0.18,0.09),Vector3.new(-0.48+(i%3)*0.24,1.2+math.floor(i/3)*0.3,-1.03),accent,nil,CFrame.Angles(0,0,math.pi/4))
			glyph.Material=Enum.Material.Neon
		end
		orbit("SatelliteOrbit",Vector3.new(0,4.25,0),1.15,accent,12)
	elseif shape == "capybara" then
		for _,side in {-1,1} do
			piece(model,"InnerEar",Vector3.new(0.43,0.52,0.13),Vector3.new(side*1.0,3.68,-0.27),pale,Enum.PartType.Ball)
			dot("SnoutFreckle",Vector3.new(side*0.36,2.05,-1.34),0.12,shade)
		end
		piece(model,"StarSatchel",Vector3.new(0.8,0.85,0.55),Vector3.new(1.45,1.25,0.15),accent)
		rod("SatchelStrap",Vector3.new(-0.9,3.4,-0.85),Vector3.new(1.25,1.65,-0.85),0.12,accent)
	elseif shape == "crown" then
		orbit("RoyalCollar",Vector3.new(0,1.12,0),1.1,accent,12)
		for i=-1,1 do
			dot("CrownGem",Vector3.new(i*0.8,4.15,-1.06),0.24,i==0 and color or pale)
			dot("CrownPearl",Vector3.new(i*0.8,4.92,0),0.25,pale)
		end
		piece(model,"RoyalCape",Vector3.new(2.5,2.45,0.25),Vector3.new(0,2.0,1.05),color:Lerp(ink,0.35))
	end
	local rarity = string.lower(spec.rarity or "")
	if rarity == "secret" or rarity == "mythic" then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Brightness = 0.7
		light.Range = 9
		light.Parent = root
	end
	if scale and scale ~= 1 then model:ScaleTo(math.clamp(scale, 0.1, 5)) end
	return model
end

return CreatureFactory
