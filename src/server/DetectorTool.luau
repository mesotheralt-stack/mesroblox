-- Cosmetic, physically welded detector. Capture authority stays in Main.server.
local DetectorTool = {}

local function removeOld(container)
	if not container then return end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("BrainrotDetector") then child:Destroy() end
	end
end

function DetectorTool.equip(player, spec)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack or not character then return end
	removeOld(backpack)
	removeOld(character)
	local tool = Instance.new("Tool")
	tool.Name = spec.name
	tool.ToolTip = "Search the sand • use DIG or press E"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("BrainrotDetector", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.38, 1.15, 0.4)
	handle.Color = Color3.fromRGB(35, 43, 49)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool
	local function piece(name, size, frame, color, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = frame
		part.Color = color
		part.Material = Enum.Material.Metal
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
		if shape then part.Shape = shape end
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	piece("Shaft", Vector3.new(0.18, 3.4, 0.18), CFrame.new(0, -1.8, -0.65) * CFrame.Angles(math.rad(25), 0, 0), spec.color)
	piece("SearchCoil", Vector3.new(0.15, 2.0, 2.0), CFrame.new(0, -3.3, -1.4) * CFrame.Angles(0, 0, math.pi / 2), spec.color, Enum.PartType.Cylinder)
	piece("CoilInset", Vector3.new(0.18, 1.45, 1.45), CFrame.new(0, -3.3, -1.4) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(27, 36, 41), Enum.PartType.Cylinder)
	piece("ControlBox", Vector3.new(0.85, 0.6, 0.5), CFrame.new(0, -0.6, -0.35), spec.color)
	local screen = piece("SignalDisplay", Vector3.new(0.63, 0.08, 0.32), CFrame.new(0, -0.27, -0.35), Color3.fromRGB(166, 255, 179))
	screen.Material = Enum.Material.Neon
	tool.Grip = CFrame.new(0, -0.25, 0)
	tool.Parent = backpack
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then humanoid:EquipTool(tool) end
	return tool
end

return DetectorTool
