-- Original, static shop attendants. These models only present existing shop
-- prompts; all purchases, trades and sales remain in the authoritative server.
local StationKeeper = {}
local V = Vector3.new
local A = CFrame.Angles
local rgb = Color3.fromRGB
local INK = rgb(43,55,50)
local IVORY = rgb(252,245,224)
local SKIN = rgb(218,168,123)
local HAIR = rgb(86,62,47)
local BRASS = rgb(201,162,88)
local ROLES = {
	Food = {name="Chef Pip",coat=rgb(238,226,198),accent=rgb(160,191,139),trousers=rgb(104,121,88),action="Browse food"},
	Gear = {name="Milo the Mechanic",coat=rgb(85,134,151),accent=rgb(220,173,98),trousers=rgb(67,88,94),action="Browse gear"},
	Sell = {name="Tessa the Trader",coat=rgb(134,112,154),accent=rgb(211,171,110),trousers=rgb(77,83,94),action="Review a sale"},
}

function StationKeeper.create(parent,frame,role)
	local spec=assert(ROLES[role],"Unknown station keeper role: "..tostring(role))
	local model=Instance.new("Model")
	model.Name="StationKeeper"
	model:SetAttribute("ShopRole",role)
	model:SetAttribute("KeeperName",spec.name)
	local function piece(name,size,position,color,material,shape,rotation)
		local object=Instance.new("Part")
		object.Name=name;object.Size=size
		object.CFrame=frame*CFrame.new(position)*(rotation or CFrame.new())
		object.Color=color;object.Material=material or Enum.Material.SmoothPlastic
		object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false
		object.TopSurface=Enum.SurfaceType.Smooth;object.BottomSurface=Enum.SurfaceType.Smooth
		if shape then object.Shape=shape end
		object.Parent=model
		return object
	end
	local function orb(name,size,position,color,material,rotation)
		return piece(name,size,position,color,material,Enum.PartType.Ball,rotation)
	end
	local root=piece("Root",V(0.15,0.15,0.15),Vector3.zero,INK)
	root.Transparency=1;model.PrimaryPart=root
	piece("Torso",V(2.05,2.2,1.1),V(0,3.65,0),spec.coat,Enum.Material.Fabric)
	piece("Head",V(1.9,1.85,1.65),V(0,5.67,0),SKIN)
	for _,side in {-1,1} do
		piece(side<0 and "LeftLeg" or "RightLeg",V(0.85,1.75,0.88),V(side*0.52,1.38,0),spec.trousers,Enum.Material.Fabric)
		piece("Boot",V(1.0,0.55,1.22),V(side*0.52,0.29,-0.17),INK)
		piece("BootSole",V(1.02,0.12,1.25),V(side*0.52,0.09,-0.17),rgb(67,69,59))
		piece(side<0 and "LeftArm" or "RightArm",V(0.72,1.85,0.86),V(side*1.42,3.66,0),spec.coat,Enum.Material.Fabric,nil,A(0,0,side*0.1))
		orb("Hand",V(0.74,0.72,0.78),V(side*1.52,2.54,-0.03),SKIN)
		piece("Cuff",V(0.76,0.25,0.9),V(side*1.5,2.99,0),spec.accent,Enum.Material.Fabric,nil,A(0,0,side*0.1))
		orb("Ear",V(0.3,0.55,0.5),V(side*0.99,5.64,0),SKIN)
		piece("ShirtCollar",V(0.47,0.48,0.12),V(side*0.28,4.54,-0.6),IVORY,Enum.Material.Fabric,nil,A(0,0,side*0.37))
		orb("EyeWhite",V(0.3,0.36,0.12),V(side*0.42,5.86,-0.85),IVORY)
		orb("EyePupil",V(0.15,0.23,0.09),V(side*0.42,5.85,-0.928),INK)
		orb("EyeGlint",V(0.052,0.062,0.04),V(side*0.42-0.036,5.92,-0.98),IVORY)
		piece("Eyebrow",V(0.35,0.08,0.08),V(side*0.42,6.15,-0.88),HAIR,nil,nil,A(0,0,side*-0.1))
		orb("Cheek",V(0.25,0.13,0.06),V(side*0.59,5.56,-0.85),rgb(234,147,126))
		piece("SmileCorner",V(0.16,0.055,0.065),V(side*0.12,5.32,-0.88),INK,nil,nil,A(0,0,side*0.35))
	end
	orb("Nose",V(0.22,0.24,0.19),V(0,5.62,-0.9),SKIN:Lerp(IVORY,0.13))
	piece("Smile",V(0.16,0.055,0.065),V(0,5.295,-0.88),INK)
	orb("HairCap",V(2.03,0.63,1.78),V(0,6.48,0.03),HAIR)
	for j=1,3 do orb("HairLock",V(0.65,0.31,0.32),V((j-2)*0.51,6.35,-0.76),HAIR,nil,A(0,0,(j-2)*0.15)) end
	if role=="Food" then
		piece("ChefApron",V(1.5,1.72,0.12),V(0,3.38,-0.62),spec.accent,Enum.Material.Fabric)
		piece("ApronPocket",V(0.85,0.46,0.08),V(0,3.11,-0.72),IVORY,Enum.Material.Fabric)
		piece("ApronWaistTie",V(2.12,0.15,1.14),V(0,3.56,0),IVORY,Enum.Material.Fabric)
		piece("ChefHatBand",V(1.99,0.36,1.76),V(0,6.69,0.02),IVORY,Enum.Material.Fabric)
		for j=1,3 do orb("ChefHatPuff",V(1.03,0.97,1.72),V((j-2)*0.59,7.19+(j==2 and 0.12 or 0),0.02),IVORY,Enum.Material.Fabric) end
	elseif role=="Gear" then
		piece("WorkshopCap",V(2.12,0.32,1.85),V(0,6.66,0.03),spec.coat,Enum.Material.Fabric)
		piece("CapVisor",V(2.08,0.13,0.75),V(0,6.52,-0.86),spec.accent,Enum.Material.Fabric)
		piece("GoggleStrap",V(1.9,0.18,0.11),V(0,6.35,-0.87),INK,Enum.Material.Fabric)
		for _,side in {-1,1} do
			piece("GoggleRim",V(0.62,0.45,0.2),V(side*0.41,6.36,-0.96),BRASS,Enum.Material.Metal)
			local lens=piece("GoggleLens",V(0.43,0.27,0.07),V(side*0.41,6.36,-1.08),rgb(159,211,209),Enum.Material.Glass)
			lens.Transparency=0.2
		end
		piece("ToolBelt",V(2.14,0.28,1.18),V(0,2.8,0),HAIR,Enum.Material.Fabric)
		piece("ToolBuckle",V(0.4,0.3,0.1),V(0,2.8,-0.66),BRASS,Enum.Material.Metal)
		piece("ToolPocket",V(0.61,0.73,0.18),V(0.68,2.62,-0.68),spec.accent,Enum.Material.Fabric)
		piece("SpannerHandle",V(0.15,0.63,0.13),V(0.69,3.07,-0.8),rgb(179,190,184),Enum.Material.Metal,nil,A(0,0,-0.13))
		for _,side in {-1,1} do piece("SpannerJaw",V(0.13,0.24,0.13),V(0.69+side*0.11,3.42,-0.8),rgb(179,190,184),Enum.Material.Metal,nil,A(0,0,side*-0.25)) end
	else
		for _,side in {-1,1} do piece("TraderLapel",V(0.42,1.13,0.12),V(side*0.61,3.88,-0.62),spec.accent,Enum.Material.Fabric,nil,A(0,0,side*-0.23)) end
		piece("TraderScarf",V(0.95,0.3,1.19),V(0,4.61,-0.03),rgb(226,184,132),Enum.Material.Fabric)
		piece("ScarfTail",V(0.42,0.8,0.12),V(-0.14,4.06,-0.7),rgb(226,184,132),Enum.Material.Fabric)
		piece("LedgerCover",V(0.96,1.15,0.18),V(-1.55,2.76,-0.5),rgb(80,111,94),Enum.Material.Fabric,nil,A(0,0,-0.16))
		piece("LedgerPages",V(0.8,0.98,0.08),V(-1.55,2.76,-0.62),IVORY,nil,nil,A(0,0,-0.16))
		piece("LedgerClasp",V(0.22,0.25,0.13),V(-1.14,2.76,-0.67),BRASS,Enum.Material.Metal)
		for j=1,3 do piece("CoatButton",V(0.13,0.13,0.09),V(0.05,2.86+j*0.36,-0.65),BRASS,Enum.Material.Metal) end
	end
	local badge=piece("KeeperNamePlaque",V(3.2,0.65,0.12),V(0,4.11,-0.8),INK,Enum.Material.Wood)
	local surface=Instance.new("SurfaceGui")
	surface.Name="KeeperIdentification";surface.Face=Enum.NormalId.Front;surface.CanvasSize=Vector2.new(480,96)
	surface.LightInfluence=0.2;surface.MaxDistance=38;surface.Parent=badge
	local label=Instance.new("TextLabel")
	label.Name="KeeperName";label.Size=UDim2.new(1,-20,1,-6);label.Position=UDim2.fromOffset(10,3)
	label.BackgroundTransparency=1;label.TextColor3=IVORY;label.Font=Enum.Font.BuilderSansMedium;label.TextSize=32
	label.Text=spec.name;label.TextTruncate=Enum.TextTruncate.AtEnd;label.Parent=surface
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name="KeeperShopPrompt";prompt.ActionText=spec.action;prompt.ObjectText=spec.name
	prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.MaxActivationDistance=15;prompt.HoldDuration=0;prompt.RequiresLineOfSight=false
	prompt:SetAttribute("Shop",role);prompt.Parent=badge
	model.Parent=parent
	return model
end

return StationKeeper
