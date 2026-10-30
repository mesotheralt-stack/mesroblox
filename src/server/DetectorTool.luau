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
	handle.CanQuery = false
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
		part.CanQuery = false
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
	-- A hollow search loop reads as an instrument instead of a solid paddle.
	-- Stronger detectors have a broader coil and an additional inner winding.
	local radiusX=spec.power>=5 and 1.16 or 0.96
	local radiusZ=spec.power>=5 and 0.84 or 0.96
	local function winding(name,factor)
		for index=1,12 do
			local function at(a)
				return Vector3.new(math.cos(a)*radiusX*factor,-3.3,-1.4+math.sin(a)*radiusZ*factor)
			end
			local a=at((index-1)*math.pi/6)
			local b=at(index*math.pi/6)
			piece(name,Vector3.new(0.14,0.12,(b-a).Magnitude+0.025),CFrame.lookAt((a+b)*0.5,b),spec.color)
		end
	end
	winding("SearchCoil",1)
	if spec.power>=6 then winding("InnerWinding",0.72) end
	piece("CoilBridge",Vector3.new(radiusX*2-0.1,0.1,0.16),CFrame.new(0,-3.3,-1.4),Color3.fromRGB(49,62,65))
	piece("ShaftCoupling",Vector3.new(0.3,0.38,0.3),CFrame.new(0,-2.42,-0.94)*CFrame.Angles(math.rad(25),0,0),Color3.fromRGB(66,81,83))
	for index=1,4 do
		local grip=piece("GripRib",Vector3.new(0.41,0.07,0.43),CFrame.new(0,-0.42+index*0.2,0),Color3.fromRGB(73,83,83))
		grip.Material=Enum.Material.SmoothPlastic
	end
	piece("ControlBox", Vector3.new(0.85, 0.6, 0.5), CFrame.new(0, -0.6, -0.35), spec.color)
	piece("DisplayBezel",Vector3.new(0.85,0.07,0.49),CFrame.new(0,-0.3,-0.35),Color3.fromRGB(35,49,52))
	local screen = piece("SignalDisplay", Vector3.new(0.63, 0.08, 0.32), CFrame.new(0, -0.27, -0.35), Color3.fromRGB(166, 255, 179))
	screen.Material = Enum.Material.Neon
	for index=1,3 do
		piece("SignalTrace",Vector3.new(0.065,0.012,0.06+index*0.045),CFrame.new(-0.23+index*0.11,-0.223,-0.35),Color3.fromRGB(48,103,86))
	end
	piece("TuningDial",Vector3.new(0.08,0.18,0.18),CFrame.new(0.33,-0.235,-0.35)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(214,218,194),Enum.PartType.Cylinder)
	tool.Grip = CFrame.new(0, -0.25, 0)
	tool.Parent = backpack
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then humanoid:EquipTool(tool) end
	return tool
end

return DetectorTool
