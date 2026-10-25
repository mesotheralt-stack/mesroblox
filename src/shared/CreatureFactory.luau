-- Original, dependency-free toy creatures. Every piece is anchored for use in
-- world displays and ViewportFrames; callers move the result with PivotTo.
local CreatureFactory = {}

local function piece(model, name, size, position, color, shape, rotation)
	local part = Instance.new("Part")
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
	if shape then part.Shape = shape end
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
	piece(model, "Body", Vector3.new(2.8, 3.1, 2.2), Vector3.new(0, 2.3, 0), color, Enum.PartType.Ball)
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
