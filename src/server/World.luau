-- Hand-built procedural scenery. Gameplay reads only the returned pit geometry
-- and destination frames; scenery never grants rewards or changes progression.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreatureFactory = require(ReplicatedStorage:WaitForChild("BrainrotShared"):WaitForChild("CreatureFactory"))
local GardenService = require(script.Parent:WaitForChild("GardenService"))

local World = {}
local cycleStarted = false
local V = Vector3.new
local rgb = Color3.fromRGB
local P = {
	wood=rgb(128,91,59), darkWood=rgb(78,62,46), lightWood=rgb(184,145,94),
	stone=rgb(161,166,145), darkStone=rgb(105,117,105), cream=rgb(240,228,194),
	leaf=rgb(91,150,88), ink=rgb(39,59,49), brass=rgb(199,164,93),
}

local function folder(parent, name)
	local item=Instance.new("Folder"); item.Name=name; item.Parent=parent; return item
end

local function part(parent, name, size, position, tint, material, shape, rotation)
	local item=Instance.new(shape=="Wedge" and "WedgePart" or "Part")
	item.Name=name; item.Size=size; item.Position=position; item.Color=tint
	item.Material=material or Enum.Material.SmoothPlastic
	item.Anchored=true; item.TopSurface=Enum.SurfaceType.Smooth; item.BottomSurface=Enum.SurfaceType.Smooth
	if shape and shape~="Wedge" then item.Shape=shape end
	if rotation then item.CFrame=CFrame.new(position)*rotation end
	item.Parent=parent
	return item
end

local function detail(parent, name, size, position, tint, material, shape, rotation)
	local item=part(parent,name,size,position,tint,material,shape,rotation)
	item.CanCollide=false; item.CanTouch=false
	return item
end

local function disk(parent,name,position,radius,height,tint,material)
	return part(parent,name,V(height,radius*2,radius*2),position,tint,material,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
end

local function plaque(parent, position, title, subtitle, tint, width)
	local board=part(parent,"PhysicalSign",V(width or 16,3.4,0.35),position,P.ink,Enum.Material.Wood)
	board.CanCollide=false
	local gui=Instance.new("SurfaceGui")
	gui.Name="Wayfinding"; gui.Face=Enum.NormalId.Front; gui.CanvasSize=Vector2.new(600,140)
	gui.LightInfluence=0.3; gui.MaxDistance=90; gui.Parent=board
	local text=Instance.new("TextLabel")
	text.Size=UDim2.new(1,-28,subtitle and 0.57 or 1,0); text.Position=UDim2.fromOffset(14,0)
	text.BackgroundTransparency=1; text.Font=Enum.Font.BuilderSansBold; text.TextSize=31
	text.TextColor3=tint or P.cream; text.Text=title; text.TextTruncate=Enum.TextTruncate.AtEnd; text.Parent=gui
	if subtitle then
		local sub=text:Clone(); sub.Size=UDim2.new(1,-28,0.43,0); sub.Position=UDim2.new(0,14,0.57,-3)
		sub.Font=Enum.Font.BuilderSans; sub.TextSize=19; sub.TextColor3=rgb(193,209,190); sub.Text=subtitle; sub.Parent=gui
	end
	return board
end

local function prompt(target,action,name,key,value)
	local object=Instance.new("ProximityPrompt")
	object.ActionText=action; object.ObjectText=name; object.HoldDuration=0
	object.KeyboardKeyCode=Enum.KeyCode.F; object.MaxActivationDistance=15; object.RequiresLineOfSight=false
	object:SetAttribute(key,value); object.Parent=target
end

local function lamp(parent,position,tint,short)
	local h=short and 4 or 10
	part(parent,"LanternPost",V(0.6,h,0.6),position+V(0,h/2,0),P.darkWood,Enum.Material.Wood)
	part(parent,"LanternBracket",V(2.6,0.35,0.5),position+V(0,h,0),P.darkWood)
	part(parent,"LanternCap",V(2.2,0.35,2.2),position+V(0,h+0.4,0),P.brass,Enum.Material.Metal)
	local glow=detail(parent,"LanternGlass",V(1.4,1.8,1.4),position+V(0,h-0.7,0),tint,Enum.Material.Neon)
	glow.Transparency=0.22
	local light=Instance.new("PointLight"); light.Color=tint; light.Brightness=1.1; light.Range=34; light.Parent=glow
end

local function crate(parent,position,scale)
	scale=scale or 1
	part(parent,"CrateBody",V(4,3.6,3.6)*scale,position+V(0,1.8*scale,0),P.lightWood,Enum.Material.WoodPlanks)
	for _,x in {-1.7,1.7} do detail(parent,"CrateIronCorner",V(0.3,3.8,3.8)*scale,position+V(x,1.8,0)*scale,P.darkWood) end
	detail(parent,"CrateBrace",V(4.5,0.3,0.2)*scale,position+V(0,1.8,-1.9)*scale,P.wood,nil,nil,CFrame.Angles(0,0,0.62))
end

local function barrel(parent,position)
	part(parent,"BarrelStaves",V(3.2,4.1,3.2),position+V(0,2.05,0),P.wood,Enum.Material.Wood,Enum.PartType.Ball)
	for _,h in {0.8,3.2} do disk(parent,"BarrelBand",position+V(0,h,0),1.56,0.23,P.darkWood,Enum.Material.Metal) end
	disk(parent,"BarrelLid",position+V(0,4,0),1.22,0.18,P.lightWood,Enum.Material.WoodPlanks)
end

local function bench(parent,position)
	for j=-1,1 do part(parent,"SeatSlat",V(10,0.3,0.65),position+V(0,2.0,j*0.8),P.lightWood,Enum.Material.WoodPlanks) end
	for h=0,1 do part(parent,"BackrestSlat",V(10,0.6,0.3),position+V(0,3+h*0.8,1.05),P.lightWood,Enum.Material.WoodPlanks) end
	for _,x in {-3.8,3.8} do
		part(parent,"BenchLeg",V(0.5,2,2.8),position+V(x,1,0),P.darkWood,Enum.Material.Metal)
		part(parent,"BackrestPost",V(0.4,3,0.4),position+V(x,2.5,1.05),P.darkWood)
	end
end

local function flowerCluster(parent,position,tint)
	for i=1,3 do
		local x,z=(i-2)*0.8,(i%2)*0.65
		detail(parent,"FlowerStem",V(0.12,1.0,0.12),position+V(x,0.55,z),rgb(74,126,67))
		detail(parent,"FlowerPetals",V(0.85,0.32,0.85),position+V(x,1.1,z),tint,nil,Enum.PartType.Ball)
		detail(parent,"FlowerHeart",V(0.27,0.18,0.27),position+V(x,1.26,z),P.cream,nil,Enum.PartType.Ball)
	end
end

local function tree(parent,position,scale,kind,tint,yaw)
	local treeFolder=folder(parent,kind==2 and "PalmTree" or kind==3 and "MoonPine" or "CloverOak")
	local brown=kind==3 and rgb(90,92,111) or P.wood
	if kind==2 then
		for j=0,4 do
			part(treeFolder,"PalmTrunkSegment",V(2.2-j*0.15,4.2,2.2-j*0.15)*scale,position+V(j*0.6,2+j*3.3,0)*scale,brown,Enum.Material.Wood,nil,CFrame.Angles(0,0,-0.14))
		end
		local crown=position+V(2.5,17,0)*scale
		for j=1,7 do
			local a=j*math.pi*2/7+yaw
			detail(treeFolder,"PalmFrond",V(3,0.6,15)*scale,crown+V(math.sin(a)*5.7,-0.5,math.cos(a)*5.7)*scale,tint,Enum.Material.Grass,"Wedge",CFrame.Angles(0,a,0)*CFrame.Angles(-0.12,0,0))
		end
		for j=1,3 do detail(treeFolder,"Coconut",V(1.4,1.7,1.4)*scale,crown+V((j-2)*0.9,-1.1,-0.8)*scale,P.darkWood,nil,Enum.PartType.Ball) end
	else
		part(treeFolder,"TaperedTrunk",V(2.6,13,2.6)*scale,position+V(0,6.5,0)*scale,brown,Enum.Material.Wood)
		for j=1,3 do
			local a=j*math.pi*2/3+yaw
			detail(treeFolder,"TreeRoot",V(1.0,1.5,5)*scale,position+V(math.sin(a)*1.8,0.65,math.cos(a)*1.8)*scale,brown,Enum.Material.Wood,nil,CFrame.Angles(0,a,0))
		end
		if kind==3 then
			for tier=1,3 do
				local w=(17-tier*3.4)*scale
				for side=0,3 do
					detail(treeFolder,"PineBough",V(w,7*scale,w/2),position+V(0,8+tier*4,0)*scale,tint:Lerp(P.cream,tier*0.035),Enum.Material.Grass,"Wedge",CFrame.Angles(0,side*math.pi/2+yaw,0))
				end
			end
		else
			for j=1,2 do part(treeFolder,"OakFork",V(1.5,8,1.5)*scale,position+V((j==1 and -1 or 1)*2.1,12,0)*scale,brown,Enum.Material.Wood,nil,CFrame.Angles(0,0,j==1 and 0.5 or -0.5)) end
			for j=1,4 do
				local a=j*math.pi/2+yaw
				detail(treeFolder,"LayeredCanopy",V(15,11,14)*scale,position+V(math.sin(a)*4.2,15+(j%2)*3,math.cos(a)*3.8)*scale,tint:Lerp(P.cream,(j%3)*0.035),Enum.Material.Grass,Enum.PartType.Ball)
			end
		end
	end
end

local function shoreline(parent,offset,index)
	local cliffs=folder(parent,"TerracedShore")
	local stone=index==3 and rgb(112,112,146) or index==2 and rgb(169,139,96) or rgb(123,135,111)
	part(cliffs,"IslandStone",V(684,18,644),offset+V(0,-16,0),stone,Enum.Material.Slate)
	part(cliffs,"LowerIslandShelf",V(655,12,615),offset+V(0,-29,0),stone:Lerp(P.darkStone,0.18),Enum.Material.Rock)
	for j=1,20 do
		local horizontal=j%2==0
		local d=-312+math.floor((j-1)/2)*69
		for _,side in {-1,1} do
			local pos=horizontal and V(d,-8-(j%3),side*323) or V(side*343,-8-(j%3),d)
			local rock=detail(cliffs,"ShorelineOutcrop",V(42+(j%4)*5,15+(j%3)*3,29),offset+pos,stone:Lerp(P.cream,(j%3)*0.035),Enum.Material.Rock,Enum.PartType.Ball,CFrame.Angles(0,j*0.37,0))
			rock.CanCollide=true
		end
	end
end

local function digSite(parent,offset,tint,id)
	local dig=folder(parent,"ExcavationSite")
	local center=offset+V(0,0.65,130)
	local size=V(320,3,280)
	local sand=part(dig,"DigZone",size,offset+V(0,-2.6,130),tint,Enum.Material.Sand)
	sand:SetAttribute("WorldId",id)
	for j=0,19 do
		for _,side in {-1,1} do
			part(dig,"RetainingStone",V(3.2,2.2,13.2),offset+V(side*162,0.3,-3+j*14),P.stone,Enum.Material.Slate)
		end
	end
	for j=0,21 do
		local x=-154+j*14.7
		if math.abs(x)>22 then part(dig,"EntranceRetainingStone",V(13.8,2.2,3),offset+V(x,0.3,-11),P.stone,Enum.Material.Slate) end
		part(dig,"RearRetainingStone",V(13.8,2.2,3),offset+V(x,0.3,271),P.stone,Enum.Material.Slate)
	end
	for j=1,4 do
		part(dig,"WideEntranceStep",V(39,0.35,3.0),offset+V(0,0.3-j*0.35,-15+j*3),P.stone,Enum.Material.Slate)
	end
	for row=1,4 do
		for col=1,5 do
			local ripple=detail(dig,"WindBrushedSand",V(38,0.025,15),offset+V(-145+col*49,-1.085,17+row*50),tint:Lerp(P.cream,(row+col)%2==0 and 0.08 or 0.025),Enum.Material.Sand,Enum.PartType.Ball,CFrame.Angles(0,0.08*(col%2),0))
			ripple.CanQuery=false
		end
	end
	for _,x in {-179,179} do
		for j=0,4 do
			part(dig,"RopeFencePost",V(0.7,3.4,0.7),offset+V(x,1.95,4+j*62),P.wood,Enum.Material.Wood)
			if j<4 then detail(dig,"RopeRail",V(0.18,0.18,62),offset+V(x,2.8,35+j*62),P.lightWood) end
		end
	end
	for _,x in {-190,190} do for _,z in {6,132,258} do lamp(dig,offset+V(x,0.3,z),rgb(255,225,164),false) end end
	local supplies=folder(dig,"ExcavationSupplies")
	crate(supplies,offset+V(-197,0.3,-18),1); crate(supplies,offset+V(-202,0.3,-23),0.7)
	barrel(supplies,offset+V(196,0.3,-22))
	local cart=part(supplies,"SurveyCart",V(7,0.5,4),offset+V(200,2,-8),P.lightWood,Enum.Material.WoodPlanks)
	for _,x in {-2.6,2.6} do for _,z in {-1.5,1.5} do
		part(supplies,"CartWheel",V(0.45,2.0,2.0),cart.Position+V(x,-1.1,z),P.darkWood,nil,Enum.PartType.Cylinder)
	end end
	detail(supplies,"SurveyDetector",V(0.3,4.8,0.3),cart.Position+V(0,2.3,0),P.brass,Enum.Material.Metal,nil,CFrame.Angles(0,0,0.45))
	plaque(dig,offset+V(-38,4.0,-25),"The dig grounds","Search the sand · capture the signal",P.cream,23)
	return center,size
end

local function fountain(parent,position,tint)
	local court=folder(parent,"GardenFountain")
	disk(court,"FountainPaving",position+V(0,0.1,0),16,0.35,P.stone,Enum.Material.Cobblestone)
	disk(court,"FountainBasin",position+V(0,1.1,0),10.5,1.9,P.cream,Enum.Material.Marble)
	local water=disk(court,"FountainWater",position+V(0,2.1,0),9.4,0.18,tint,Enum.Material.Glass); water.CanCollide=false; water.Transparency=0.16
	disk(court,"FountainPedestal",position+V(0,3.4,0),2.7,4,P.cream,Enum.Material.Marble)
	disk(court,"UpperFountainBowl",position+V(0,5.4,0),4.5,0.6,P.cream,Enum.Material.Marble)
	for j=1,8 do
		local a=j*math.pi/4
		local jet=detail(court,"WaterRibbon",V(0.14,3.7,0.18),position+V(math.sin(a)*3.5,3.6,math.cos(a)*3.5),tint,Enum.Material.Glass,nil,CFrame.Angles(math.sin(a)*0.26,0,math.cos(a)*0.26))
		jet.Transparency=0.25
	end
	detail(court,"FountainFinial",V(2.0,2.8,2.0),position+V(0,7.1,0),tint,Enum.Material.Glass,Enum.PartType.Ball)
end

local function shop(parent,position,food)
	local building=folder(parent,food and "FoodMarket" or "GearWorkshop")
	local color=food and rgb(210,126,97) or rgb(93,137,158)
	part(building,"FoundationTrim",V(40,0.5,29),position+V(0,0.55,0),P.stone,Enum.Material.Slate)
	part(building,"ShopFloor",V(37,0.4,26),position+V(0,0.95,0),P.lightWood,Enum.Material.WoodPlanks)
	for _,x in {-17,17} do for _,z in {-11,11} do part(building,"CarvedTimberPost",V(1.3,11.5,1.3),position+V(x,6.5,z),P.wood,Enum.Material.Wood) end end
	part(building,"PlasterBackWall",V(35,8,0.8),position+V(0,5.2,11),P.cream,Enum.Material.Concrete)
	for _,x in {-11,11} do
		part(building,"BackWindowFrame",V(7.3,5,0.2),position+V(x,6.3,10.45),P.wood,Enum.Material.Wood)
		detail(building,"BackWindowPane",V(6.4,4.1,0.15),position+V(x,6.3,10.25),rgb(171,213,202),Enum.Material.Glass)
		part(building,"WindowMullion",V(0.25,4.4,0.3),position+V(x,6.3,10.05),P.lightWood)
	end
	for _,side in {-1,1} do
		part(building,"GabledRoof",V(23,0.8,31),position+V(side*10,14.0,0),color,Enum.Material.WoodPlanks,nil,CFrame.Angles(0,0,side*-0.31))
		part(building,"RoofFascia",V(23,0.45,0.7),position+V(side*10,14.05,-15.5),P.cream,nil,nil,CFrame.Angles(0,0,side*-0.31))
	end
	part(building,"RoofRidge",V(0.8,0.8,32),position+V(0,17.4,0),P.darkWood)
	local counter=part(building,"ShopCounter",V(31,3.4,3.6),position+V(0,3.0,-6.5),P.wood,Enum.Material.WoodPlanks)
	part(building,"CounterTop",V(32,0.35,4.0),position+V(0,4.9,-6.5),P.lightWood,Enum.Material.Wood)
	for _,x in {-10,10} do part(building,"CabinetInset",V(7.8,2.3,0.1),position+V(x,3.1,-8.36),color) end
	part(building,"CashRegister",V(2.1,1.3,1.8),position+V(11,5.7,-6.2),P.darkStone,Enum.Material.Metal)
	detail(building,"RegisterScreen",V(1.4,0.8,0.1),position+V(11,5.9,-7.14),rgb(169,219,171),Enum.Material.Neon)
	for _,h in {4.5,7.4} do part(building,"BackShelf",V(29,0.35,2.4),position+V(0,h,8.6),P.wood,Enum.Material.Wood) end
	for j=1,7 do
		local x=-12+(j-1)*4
		if food then
			part(building,"ProduceBasket",V(3.3,0.9,2.6),position+V(x,5.3,-6.1),P.lightWood,Enum.Material.Wood)
			for k=1,3 do detail(building,"FreshProduce",V(0.9,0.9,0.9),position+V(x+(k-2)*0.8,6.1,-6.1),j%2==0 and rgb(229,116,93) or rgb(191,202,100),nil,Enum.PartType.Ball) end
			part(building,"FlourJar",V(1.5,2,1.5),position+V(x,5.7,8.5),P.cream,nil,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
		else
			part(building,"EquipmentCase",V(2.8,1.6,1.6),position+V(x,5.9,8.5),j%2==0 and color or P.darkStone,Enum.Material.Metal)
			detail(building,"WorkshopSpareShaft",V(0.22,2.5,0.22),position+V(x,6.5,-6),P.brass,Enum.Material.Metal,nil,CFrame.Angles(0,0,0.25))
			detail(building,"SpareSearchCoil",V(0.12,1.8,1.8),position+V(x,5.3,-6),color,Enum.Material.Metal,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
		end
	end
	for _,x in {-17,17} do lamp(building,position+V(x,1.0,-12),rgb(255,227,172),true) end
	plaque(building,position+V(0,10,-13.3),food and "Food market" or "Gear workshop",food and "Fresh snacks · five-minute rotation" or "Detectors · growth & income boosts",P.cream,27)
	prompt(counter,"Browse",food and "Food market" or "Gear workshop","Shop",food and "Food" or "Gear")
	crate(building,position+V(-23,0.3,3),0.9); barrel(building,position+V(23,0.3,7))
end

local function pond(parent,position,palm)
	local grove=folder(parent,palm and "PalmOasis" or "CloverPond")
	local tint=palm and rgb(181,180,126) or rgb(179,188,141)
	detail(grove,"PondShore",V(83,1.2,65),position,tint,Enum.Material.Sand,Enum.PartType.Ball)
	local water=detail(grove,"PondWater",V(71,0.3,53),position+V(0,0.8,0),rgb(93,169,166),Enum.Material.Glass,Enum.PartType.Ball); water.Transparency=0.12
	for j=1,7 do
		local a=j*math.pi*2/7
		detail(grove,"PondReed",V(0.13,3+j%3,0.13),position+V(math.cos(a)*36,2.0,math.sin(a)*26),rgb(99,137,76))
		detail(grove,"ReedHead",V(0.4,1,0.4),position+V(math.cos(a)*36,3.5,math.sin(a)*26),P.wood,nil,Enum.PartType.Ball)
	end
	for j=1,5 do detail(grove,"LilyPad",V(4.2,0.15,3.8),position+V(-27+j*7,1.1,8+(j%2)*6),rgb(117,161,95),nil,Enum.PartType.Ball) end
	if not palm then
		for j=-8,8 do
			part(grove,"ArchedBridgePlank",V(14,0.45,3.1),position+V(0,1.6+math.cos(j*math.pi/18)*1.6,j*3.1),P.lightWood,Enum.Material.WoodPlanks)
			if j%3==0 then for _,x in {-7,7} do part(grove,"BridgePost",V(0.5,4.0,0.5),position+V(x,3.4,j*3.1),P.wood) end end
		end
		for _,x in {-7,7} do part(grove,"BridgeHandrail",V(0.45,0.45,50),position+V(x,5.2,0),P.wood) end
		local tablePos=position+V(51,0,12)
		part(grove,"PicnicTableTop",V(11,0.45,6),tablePos+V(0,3,0),P.lightWood,Enum.Material.WoodPlanks)
		for _,x in {-3.7,3.7} do part(grove,"PicnicTableLeg",V(0.8,3.0,4),tablePos+V(x,1.5,0),P.wood) end
		for _,z in {-5,5} do part(grove,"PicnicBench",V(11,0.6,2),tablePos+V(0,1.6,z),P.lightWood) end
		part(grove,"PicnicCloth",V(7,0.05,4),tablePos+V(0,3.26,0),rgb(223,158,128))
		detail(grove,"PicnicFruitBowl",V(2.2,0.7,2.2),tablePos+V(0,3.6,0),P.cream,nil,Enum.PartType.Ball)
	end
	return grove
end

local function windmill(parent,position)
	local landmark=folder(parent,"CloverWindmill")
	disk(landmark,"WindmillFoundation",position+V(0,0.3,0),15,0.6,P.stone,Enum.Material.Slate)
	for tier=1,4 do
		disk(landmark,"WindmillTower",position+V(0,4+(tier-1)*7,0),8.3-tier*0.7,7.2,P.cream,Enum.Material.Concrete)
	end
	disk(landmark,"TowerTopRim",position+V(0,29,0),6.5,0.65,P.wood,Enum.Material.Wood)
	part(landmark,"RoofPeak",V(13,6,12),position+V(0,31.6,0),rgb(185,115,94),Enum.Material.WoodPlanks,"Wedge")
	part(landmark,"WindmillDoor",V(4.6,7.1,0.5),position+V(0,3.9,7.8),P.darkWood,Enum.Material.WoodPlanks)
	for _,h in {13,21} do
		part(landmark,"TowerWindowFrame",V(3,4.2,0.3),position+V(0,h,6.4),P.wood)
		detail(landmark,"TowerWindow",V(2.2,3.2,0.2),position+V(0,h,6.65),rgb(145,194,193),Enum.Material.Glass)
	end
	local hub=position+V(0,24,8.5)
	part(landmark,"MillAxle",V(3.4,3.4,2.2),hub,P.wood,nil,Enum.PartType.Cylinder,CFrame.Angles(0,math.pi/2,0))
	for j=0,3 do
		local a=j*math.pi/2+0.32
		local x,y=math.sin(a),math.cos(a)
		part(landmark,"SailSpar",V(1.0,17,0.6),hub+V(x*8.5,y*8.5,0),P.wood,Enum.Material.Wood,nil,CFrame.Angles(0,0,-a))
		part(landmark,"LinenSail",V(4.2,10.8,0.2),hub+V(x*11.2+y*1.4,y*11.2-x*1.4,0.4),P.cream,Enum.Material.Fabric,nil,CFrame.Angles(0,0,-a))
		for rib=-1,1 do detail(landmark,"SailRib",V(4.5,0.16,0.18),hub+V(x*(11.2+rib*3.8)+y*1.4,y*(11.2+rib*3.8)-x*1.4,0.58),P.lightWood,nil,nil,CFrame.Angles(0,0,-a)) end
	end
	for j=1,3 do crate(landmark,position+V(13+j*3.1,0.3,-3+(j%2)*5),0.8) end
	plaque(landmark,position+V(0,4.2,13),"Clover flour mill","Home-grown snacks for hungry discoveries",P.cream,22)
end

local function sunRuins(parent,position)
	local ruins=folder(parent,"SunArchSanctuary")
	local tint=rgb(203,172,121)
	for j=1,3 do part(ruins,"SanctuaryStep",V(77-j*7,0.6,57-j*5),position+V(0,j*0.6,0),tint,Enum.Material.Sandstone) end
	for _,side in {-1,1} do
		local column=position+V(side*17,1.8,0)
		part(ruins,"ColumnFoot",V(9,1.2,9),column+V(0,0.6,0),tint,Enum.Material.Sandstone)
		part(ruins,"FlutedColumn",V(6.2,21,6.2),column+V(0,11.5,0),tint,Enum.Material.Sandstone)
		for j=1,4 do detail(ruins,"ColumnGroove",V(0.18,17,0.2),column+V(-2.3+j*0.9,11.7,-3.15),rgb(167,138,93),Enum.Material.Sandstone) end
		part(ruins,"CarvedCapital",V(9,1.5,9),column+V(0,22.3,0),tint,Enum.Material.Sandstone)
	end
	for j=-3,3 do
		local a=j*0.22
		part(ruins,"ArchVoussoir",V(5.1,5.8,7),position+V(math.sin(a)*26,21+math.cos(a)*9,0),tint:Lerp(P.cream,(j%2)*0.03),Enum.Material.Sandstone,nil,CFrame.Angles(0,0,-a))
	end
	disk(ruins,"SunAltarBase",position+V(0,3,10),7,1,P.brass,Enum.Material.Sandstone)
	detail(ruins,"SunMedallion",V(0.6,8,8),position+V(0,8,10),P.brass,Enum.Material.Metal,Enum.PartType.Cylinder,CFrame.Angles(0,math.pi/2,0))
	for j=1,8 do
		local a=j*math.pi/4
		detail(ruins,"SunRayCarving",V(0.6,2.8,0.5),position+V(math.sin(a)*5,8+math.cos(a)*5,10),P.brass,nil,nil,CFrame.Angles(0,0,-a))
	end
	for j=1,5 do
		local x=-34+(j%2)*68
		part(ruins,"BrokenColumn",V(5,4+j,5),position+V(x,3+j/2,-18+j*7),tint,Enum.Material.Sandstone,nil,CFrame.Angles(0,j,0.12*(j%2)))
	end
	plaque(ruins,position+V(0,5,-22),"The sun archive","An old survey station, reclaimed by sand",P.cream,24)
end

local function crystalCluster(parent,position,scale,tint)
	for j=1,4 do
		local a=j*math.pi/2
		local h=(j%2==0 and 7 or 4.5)*scale
		local pos=position+V(math.sin(a)*1.6*scale,h/2,math.cos(a)*1.6*scale)
		local stem=detail(parent,"CrystalPrism",V(1.4*scale,h,1.4*scale),pos,tint,Enum.Material.Glass,nil,CFrame.Angles(0,a,0.1*math.sin(a)))
		stem.Transparency=0.16
		detail(parent,"CrystalTip",V(1.4,1.7,1.4)*scale,pos+V(0,h/2+0.7*scale,0),tint,Enum.Material.Neon,"Wedge",CFrame.Angles(0,a,0))
	end
end

local function observatory(parent,position)
	local place=folder(parent,"MoonwatchObservatory")
	local stone=rgb(136,144,172)
	for j=1,3 do disk(place,"ObservatoryTerrace",position+V(0,j*0.65,0),39-j*3.5,0.65,stone,Enum.Material.Slate) end
	for j=1,8 do
		local a=j*math.pi/4
		local pos=position+V(math.sin(a)*25,8.5,math.cos(a)*25)
		part(place,"ObservatoryColumn",V(2.2,13,2.2),pos,stone,Enum.Material.Marble)
		detail(place,"ColumnInlay",V(0.12,9,0.12),pos+V(-0.8,0,-1.1),rgb(178,213,218),Enum.Material.Neon)
	end
	for j=1,16 do
		local a=j*math.pi*2/16
		part(place,"DomeCornice",V(11.0,1.2,2.8),position+V(math.sin(a)*26.6,15.4,math.cos(a)*26.6),stone,Enum.Material.Marble,nil,CFrame.Angles(0,a,0))
	end
	local dome=detail(place,"ObservatoryGlassDome",V(52,22,52),position+V(0,20,0),rgb(143,173,205),Enum.Material.Glass,Enum.PartType.Ball)
	dome.Transparency=0.6
	for j=1,6 do
		local a=j*math.pi/3
		detail(place,"DomeSpire",V(0.5,12,0.5),position+V(math.sin(a)*23,23,math.cos(a)*23),P.brass,nil,nil,CFrame.Angles(math.sin(a)*0.45,0,math.cos(a)*0.45))
	end
	part(place,"TelescopePedestal",V(3.0,8.2,3.0),position+V(0,6.1,0),stone,Enum.Material.Metal)
	part(place,"TelescopeBarrel",V(19,5.6,5.6),position+V(0,14.5,0),rgb(70,87,117),Enum.Material.Metal,Enum.PartType.Cylinder,CFrame.Angles(0,0,0.35))
	for _,x in {-8,0,8} do
		part(place,"TelescopeBrassRing",V(0.75,6.2,6.2),position+V(math.cos(0.35)*x,14.5+math.sin(0.35)*x,0),P.brass,Enum.Material.Metal,Enum.PartType.Cylinder,CFrame.Angles(0,0,0.35))
	end
	local lens=detail(place,"TelescopeLens",V(0.2,4.7,4.7),position+V(math.cos(0.35)*9.6,14.5+math.sin(0.35)*9.6,0),rgb(165,229,231),Enum.Material.Glass,Enum.PartType.Cylinder,CFrame.Angles(0,0,0.35)); lens.Transparency=0.25
	for j=1,4 do part(place,"ObservatoryEntranceStep",V(18,0.45,5.0),position+V(0,j*0.45,-42+j*4.5),stone,Enum.Material.Slate) end
	plaque(place,position+V(-21,4.5,-29),"Moonwatch observatory","Follow the stars beneath your feet",P.cream,23)
end

local function landscapes(parent,offset,index,rng)
	local vegetation=folder(parent,"Woodland")
	local tints={rgb(94,155,87),rgb(103,154,103),rgb(89,139,143)}
	for j=1,23 do
		local side=j%2==0 and -1 or 1
		local x=side*rng:NextNumber(215,308)
		local z=rng:NextNumber(-298,286)
		-- Landmarks reserve the rear corners; trees occupy broad side groves.
		if z< -105 then z=60+(j%4)*56 end
		tree(vegetation,offset+V(x,0.3,z),rng:NextNumber(0.85,1.25),index,tints[index],j*0.9)
	end
	-- Rear and far-edge stands give the island a composed woodland outline,
	-- not just isolated trees along the sides of a flat rectangle.
	for j=1,10 do
		local x=-166+(j-1)*37
		local z=-292+(j%3)*5
		tree(vegetation,offset+V(x,0.3,z),0.92+(j%4)*0.095,index,tints[index]:Lerp(P.cream,(j%2)*0.035),j*1.37)
	end
	for j=1,9 do
		local x=-276+(j-1)*69
		local z=305+(j%2)*6
		tree(vegetation,offset+V(x,0.3,z),0.91+(j%3)*0.12,index,tints[index],j*0.73)
	end
	for _,x in {-265,-109,111,267} do
		local z=math.abs(x)>200 and 295 or -294
		part(vegetation,"WoodlandHill",V(57,17,39),offset+V(x,-4.4,z),tints[index]:Lerp(P.darkStone,0.07),Enum.Material.Grass,Enum.PartType.Ball)
	end
	for j=1,9 do
		local x=-168+(j-1)*42
		local z=j%2==0 and -264 or 289
		for k=-1,1 do
			detail(vegetation,"WoodlandShrub",V(7,5.4+(k%2)*1.3,7),offset+V(x+k*3.6,1.5,z+(k%2)*2.5),tints[index]:Lerp(P.ink,0.12+(j%2)*0.05),Enum.Material.Grass,Enum.PartType.Ball)
		end
	end
	for j=1,28 do
		local side=j%2==0 and -1 or 1
		local point=offset+V(side*rng:NextNumber(218,319),0.35,rng:NextNumber(-290,290))
		for blade=1,3 do
			detail(vegetation,"GrassTuft",V(0.3,1.6+(blade%2)*0.4,1.1),point+V((blade-2)*0.45,0.6,0),tints[index]:Lerp(P.cream,0.12),Enum.Material.Grass,"Wedge",CFrame.Angles(0,j,0.1*(blade-2)))
		end
		if j%3==0 then
			if index==3 then crystalCluster(vegetation,point,0.4,rgb(167,188,236))
			else flowerCluster(vegetation,point,index==1 and rgb(234,204,145) or rgb(221,150,108)) end
		end
	end
	for _,side in {-1,1} do
		local hill=part(vegetation,"LandscapedMound",V(64,19,57),offset+V(side*294,-4,-285),tints[index],Enum.Material.Grass,Enum.PartType.Ball)
		bench(vegetation,offset+V(side*126,0.3,-171))
		for j=1,12 do
			local x=side*(32+j*14)
			if side<0 or index==3 or j<12 then
				part(vegetation,"GardenTrailPaver",V(13.0,0.15,8),offset+V(x,0.42,-171),P.stone,Enum.Material.Slate,nil,CFrame.Angles(0,(j%2)*0.045,0))
			end
		end
		for j=1,3 do
			if side<0 or index==3 then
				part(vegetation,"LandmarkApproachPaver",V(13,0.15,8),offset+V(side*(200+j*13),0.42,-171),P.stone,Enum.Material.Slate)
			end
		end
	end
	local trails=folder(vegetation,"LandmarkTrails")
	if index==1 then
		-- The bridge runs along Z; approach its open near end instead of the
		-- midpoint of the pond. Small stairs meet the raised wooden decking.
		for j=1,3 do part(trails,"PondApproachPaver",V(9,0.16,11),offset+V(192,0.44,-171+j*10),P.stone,Enum.Material.Slate) end
		for j=1,3 do part(trails,"BridgeApproachPaver",V(13,0.16,8),offset+V(193+j*14,0.44,-138),P.stone,Enum.Material.Slate) end
		for j=1,4 do part(trails,"BridgeEntranceStep",V(14,0.48,2.5),offset+V(235,0.38+j*0.48,-136-j*2.5),P.lightWood,Enum.Material.WoodPlanks) end
	elseif index==2 then
		for j=1,3 do part(trails,"ArchiveApproachPaver",V(10,0.16,11),offset+V(-239,0.43,-171-j*9),P.stone,Enum.Material.Slate) end
		for j=1,4 do part(trails,"OasisShorePaver",V(11,0.16,9),offset+V(194,0.43,-171-j*10),P.stone,Enum.Material.Slate) end
		for j=1,6 do part(trails,"OasisCanopyPaver",V(12,0.16,8),offset+V(194+j*14,0.43,-214),P.stone,Enum.Material.Slate) end
	else
		for j=1,5 do part(trails,"ObservatorySidePaver",V(10,0.16,11),offset+V(-196,0.44,-171-j*10),P.stone,Enum.Material.Slate) end
		for j=1,3 do part(trails,"ObservatoryEntrancePaver",V(13,0.16,9),offset+V(-196-j*14,0.44,-222),P.stone,Enum.Material.Slate) end
		for j=1,4 do part(trails,"CrystalGardenPaver",V(10,0.16,11),offset+V(198,0.44,-171-j*12),P.stone,Enum.Material.Slate) end
	end
	local landmarks=folder(parent,"Landmarks")
	if index==1 then
		windmill(landmarks,offset+V(-246,0.3,-186))
		pond(landmarks,offset+V(235,0.4,-171),false)
	elseif index==2 then
		sunRuins(landmarks,offset+V(-240,0.3,-190))
		local oasis=pond(landmarks,offset+V(232,0.4,-174),true)
		for j=1,5 do
			local a=j*math.pi*2/5
			tree(oasis,offset+V(232+math.sin(a)*47,0.3,-174+math.cos(a)*34),1.0,2,tints[index],a)
		end
		part(oasis,"OasisCanopy",V(20,0.45,14),offset+V(287,10,-207),rgb(202,154,109),Enum.Material.Fabric)
		for _,x in {279,295} do part(oasis,"CanopyPost",V(0.7,10,0.7),offset+V(x,5,-207),P.wood) end
	else
		observatory(landmarks,offset+V(-240,0.3,-190))
		local garden=folder(landmarks,"AstralCrystalGarden")
		for j=1,7 do
			local a=j*math.pi*2/7
			crystalCluster(garden,offset+V(231+math.sin(a)*23,0.3,-176+math.cos(a)*28),0.9+(j%3)*0.25,rgb(157,171+(j%2)*23,221))
		end
		for j=1,7 do
			local pos=offset+V(207+(j%3)*16,0.3,-238+math.floor(j/3)*16)
			part(garden,"MoonMushroomStem",V(1.2,4,1.2),pos+V(0,2,0),rgb(183,193,200),nil,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
			detail(garden,"MoonMushroomCap",V(6,1.6,6),pos+V(0,4.1,0),rgb(150,198,213),Enum.Material.Neon,Enum.PartType.Ball)
			for k=1,3 do local a=k*math.pi*2/3; detail(garden,"MushroomSpot",V(0.7,0.15,0.7),pos+V(math.sin(a)*1.8,4.9,math.cos(a)*1.8),P.cream,nil,Enum.PartType.Ball) end
		end
	end
end

local function centralHub(parent,result)
	local hub=folder(parent,"CloverVillage")
	part(hub,"VillagePlaza",V(200,0.2,104),V(0,0.42,-129),rgb(190,191,158),Enum.Material.Cobblestone)
	part(hub,"PlazaInlay",V(192,0.04,96),V(0,0.54,-129),rgb(210,207,175),Enum.Material.Slate)
	part(hub,"CentralWalkway",V(22,0.2,150),V(0,0.44,-76),rgb(218,211,180),Enum.Material.Cobblestone)
	for _,side in {-1,1} do
		part(hub,"ShopApproach",V(70,0.18,16),V(side*43,0.45,-88),rgb(218,211,180),Enum.Material.Cobblestone)
		part(hub,"GalleryWalkway",V(12,0.16,78),V(side*28,0.43,-202),rgb(210,207,175),Enum.Material.Cobblestone)
		for j=1,5 do detail(hub,"WalkwayInset",V(0.6,0.06,6),V(side*11,0.57,-132+j*25),rgb(177,172,138)) end
		lamp(hub,V(side*105,0.3,-97),rgb(255,229,179),false)
		lamp(hub,V(side*105,0.3,-159),rgb(255,229,179),false)
		flowerCluster(hub,V(side*93,0.55,-113),rgb(236,192,143))
	end
	fountain(hub,V(0,0.55,-150),rgb(114,183,178))
	shop(hub,V(-64,0,-66),true); shop(hub,V(64,0,-66),false)
	local sell=folder(hub,"TradingStation")
	local sellPad=part(sell,"SellArea",V(30,0.3,20),V(-64,0.65,-118),rgb(196,174,114),Enum.Material.Slate)
	part(sell,"TradingCounter",V(17,2.3,4),V(-64,2,-124),P.wood,Enum.Material.WoodPlanks)
	disk(sell,"TradingScalePan",V(-64,3.7,-124),2.1,0.2,P.brass,Enum.Material.Metal)
	part(sell,"ScaleBalance",V(0.4,4.0,0.4),V(-64,5.3,-124),P.brass,Enum.Material.Metal)
	part(sell,"ScaleBeam",V(7,0.3,0.3),V(-64,7.2,-124),P.brass,Enum.Material.Metal)
	plaque(sell,V(-64,6,-130),"Trading post","Review your creature before selling",P.cream,25)
	crate(sell,V(-84,0.3,-118),0.85); prompt(sellPad,"Sell","Trading post","Shop","Sell")
	local home=part(hub,"HomePad",V(24,0.25,19),V(0,0.66,-106),rgb(164,194,143),Enum.Material.Slate)
	plaque(hub,V(0,5.3,-112),"Brainrot Bloom","Find it · feed it · watch it flourish",P.cream,24)
	result.spawnCFrame=CFrame.new(0,5,-91)*CFrame.Angles(0,math.pi,0)
	result.destinations.Home=result.spawnCFrame
	result.destinations.Food=CFrame.new(-64,5,-86)*CFrame.Angles(0,math.pi,0)
	result.destinations.Gear=CFrame.new(64,5,-86)*CFrame.Angles(0,math.pi,0)
	result.destinations.Sell=CFrame.new(-64,5,-113)
	local spawn=Instance.new("SpawnLocation"); spawn.Name="GardenSpawn"; spawn.Size=V(8,0.2,8)
	spawn.CFrame=CFrame.new(0,0.85,-91); spawn.Anchored=true; spawn.Transparency=1; spawn.CanCollide=false; spawn.Neutral=true; spawn.Duration=0; spawn.Parent=hub
end

local function gallery(parent,config,result)
	local grove=folder(parent,"RarityPreviewGrove")
	part(grove,"GalleryPaving",V(226,0.2,35),V(0,0.45,-223),rgb(174,187,159),Enum.Material.Slate)
	plaque(grove,V(0,6.3,-247),"The discovery garden","Seven rarities waiting beneath the sand",P.cream,27)
	for i,rarity in config.Rarities do
		local specimen
		for _,candidate in config.Creatures do if candidate.rarity==rarity.id then specimen=candidate;break end end
		if specimen then
			local x=(i-4)*31
			local frame=CFrame.new(x,1.2,-222)*CFrame.Angles(0,math.pi,0)
			disk(grove,"DisplayPlinth",V(x,0.8,-222),5.1,0.6,P.cream,Enum.Material.Marble)
			disk(grove,"PlinthInlay",V(x,1.12,-222),4.5,0.08,rarity.color,Enum.Material.Slate)
			local creature=CreatureFactory.create(specimen,0.85); creature.Name=rarity.id.."Preview"; creature:SetAttribute("DecorativePreview",true); creature:PivotTo(frame); creature.Parent=grove
			plaque(grove,V(x,2.1,-214),rarity.name,specimen.name,rarity.color,12)
			table.insert(result.displaySlots,frame)
		end
	end
end

function World.startDayNight()
	if cycleStarted then return end
	cycleStarted=true
	Lighting.ClockTime=9; Lighting.Brightness=2.1; Lighting.GlobalShadows=true
	Lighting.Ambient=rgb(102,113,141); Lighting.OutdoorAmbient=rgb(138,151,164)
	local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density=0.19; atmosphere.Color=rgb(205,232,255); atmosphere.Decay=rgb(161,186,211); atmosphere.Parent=Lighting
	task.spawn(function()
		local start=os.clock()
		while true do Lighting.ClockTime=(9+(os.clock()-start)/30)%24;task.wait(0.5) end
	end)
end

function World.build(config)
	local old=Workspace:FindFirstChild("BrainrotWorld"); if old then old:Destroy() end
	local scene=folder(Workspace,"BrainrotWorld")
	-- FallenPartsDestroyHeight is intentionally configured in the place file:
	-- normal server scripts lack the PluginOrOpenCloud capability to set it.
	local ocean=detail(scene,"Ocean",V(4000,3,1600),V(1040,-20,0),rgb(70,156,177),Enum.Material.Glass)
	ocean.Transparency=0.16
	local result={destinations={},pits={},displaySlots={}}
	local ids={"Meadow","Dunes","Cosmic"}
	local grass={rgb(105,163,87),rgb(141,171,104),rgb(99,145,136)}
	local sand={rgb(231,208,153),rgb(224,180,114),rgb(178,170,205)}
	local rng=Random.new(74119)
	for index,id in ids do
		local island=Instance.new("Model"); island.Name=id; island.Parent=scene
		local offset=V((index-1)*1040,0,0)
		shoreline(island,offset,index)
		-- A lower full-size base plus four surrounding lawns leaves a real
		-- recessed sand basin instead of laying the sand on top of the grass.
		part(island,"Grass",V(700,6,660),offset+V(0,-7,0),grass[index],Enum.Material.Grass)
		part(island,"NorthernLawn",V(700,6,320),offset+V(0,-2.7,-170),grass[index],Enum.Material.Grass)
		part(island,"SouthernLawn",V(700,6,60),offset+V(0,-2.7,300),grass[index],Enum.Material.Grass)
		for _,side in {-1,1} do part(island,"SideLawn",V(190,6,280),offset+V(side*255,-2.7,130),grass[index],Enum.Material.Grass) end
		local center,size=digSite(island,offset,sand[index],id)
		result.pits[id]={center=center,size=size}
		result.destinations[id]=CFrame.new(offset+V(0,4,7))*CFrame.Angles(0,math.pi,0)
		part(island,"ExpeditionWalkway",V(22,0.18,146),offset+V(0,0.44,-91),rgb(207,203,170),Enum.Material.Cobblestone)
		local name=config.Worlds[index] and config.Worlds[index].name or id
		plaque(island,offset+V(39,4.3,-26),name,"Choose Dig while standing in the sand",P.cream,24)
		landscapes(island,offset,index,rng)
		-- Every world's arrival area has a physical travel gate, including the
		-- starter world. The world selection menu is opened here, not from HUD.
		local portal=folder(island,"WorldTravelPortal")
		local entrance=offset+V(-38,0,-25)
		part(portal,"PortalLanding",V(27,0.3,13),entrance+V(0,0.48,0),P.stone,Enum.Material.Slate)
		for _,side in {-1,1} do
			part(portal,"PortalPillar",V(2.4,16,3),entrance+V(side*9,8,0),P.stone,Enum.Material.Slate)
			detail(portal,"PortalRune",V(0.25,8,0.15),entrance+V(side*9,8,-1.6),sand[index]:Lerp(P.cream,0.35),Enum.Material.Neon)
		end
		part(portal,"PortalLintel",V(22,3,4),entrance+V(0,16,0),P.stone,Enum.Material.Slate)
		local veil=detail(portal,"WorldPortal",V(15,14,0.3),entrance+V(0,8,0),sand[index]:Lerp(rgb(151,220,211),0.45),Enum.Material.Neon)
		veil.Transparency=0.55
		veil:SetAttribute("WorldId",id)
		plaque(portal,entrance+V(0,19.5,-1),"World portal","Travel · unlock new worlds",P.cream,23)
		prompt(veil,"Travel to worlds","World portal","WorldTravel",true)
	end
	centralHub(scene,result); gallery(scene,config,result)
	result.gardens=GardenService.build(scene,config)
	World.startDayNight()
	return result
end

return World
