-- Hand-built procedural scenery. Gameplay reads only the returned pit geometry
-- and destination frames; scenery never grants rewards or changes progression.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
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
	local stone=index==3 and rgb(89,137,151) or index==2 and rgb(155,108,77) or rgb(130,148,116)
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

-- Continuous collision lives inside sculpted strata. Overlapping stone cores
-- keep every edge closed while the visible faces read as natural escarpments.
local function cliffSegment(parent,position,width,depth,height,index,seed,yaw,inward)
	local tones={rgb(153,166,143),rgb(169,111,77),rgb(91,139,151)}
	local tint=tones[index]:Lerp(P.cream,(seed%5)*0.018)
	part(parent,"CliffCore",V(width+0.8,height,depth),position+V(0,height/2-5,0),tint,Enum.Material.Rock,nil,CFrame.Angles(0,yaw,0))
	-- Large, overlapping weathered masses cover the straight collision cores.
	-- Varied summits break their silhouette instead of repeating flat wall caps.
	part(parent,"WeatheredRockButtress",V(width*1.5,height*(1.35+(seed%3)*0.04),depth*2),position+inward*(depth*0.08)+V(0,height*0.40,0),tint:Lerp(P.cream,0.035+(seed%3)*0.03),index==2 and Enum.Material.Sandstone or Enum.Material.Rock,Enum.PartType.Ball,CFrame.Angles(0,yaw,0))
	local along=V(math.cos(yaw),0,-math.sin(yaw))
	part(parent,"BrokenRockSummit",V(width*(0.64+(seed%3)*0.08),height*(0.60+(seed%2)*0.12),depth*1.7),position+along*((seed%3-1)*width*0.12)+V(0,height*(0.81+(seed%3)*0.035),0),tint:Lerp(P.darkStone,0.05+(seed%3)*0.045),Enum.Material.Rock,"Wedge",CFrame.Angles(0,yaw+(seed%2)*math.pi,0)*CFrame.Angles((seed%3-1)*0.13,0,(seed%2==0 and -1 or 1)*0.12))
	detail(parent,"FracturedMineralPlate",V(width*0.72,height*0.37,depth*0.63),position+inward*(depth*0.73)+along*(width*0.12)+V(0,height*0.31,0),tint:Lerp(P.cream,index==2 and 0.20 or 0.12),index==2 and Enum.Material.Sandstone or Enum.Material.Slate,"Wedge",CFrame.Angles(0,yaw+(seed%2)*math.pi,0)*CFrame.Angles(0.1,0,(seed%2==0 and -0.1 or 0.15)))
	local toe=part(parent,"WeatheredCliffFoot",V(width*0.64,12+(seed%3)*2,depth*1.12),position+inward*(depth*0.46)+V(0,2,0),tint:Lerp(P.darkStone,0.12),Enum.Material.Rock,Enum.PartType.Ball,CFrame.Angles(0,yaw+seed*0.13,0))
	toe.CanTouch=false
	if index==1 and seed%3==0 then
		detail(parent,"ClingingCliffMoss",V(width*0.46,7,depth*0.8),position+inward*(depth*0.64)+V(0,height*0.68,0),rgb(113,143,99),Enum.Material.Grass,Enum.PartType.Ball,CFrame.Angles(0,yaw,0.14))
	elseif index==3 and seed%2==0 then
		detail(parent,"ExposedQuartzVein",V(width*0.28,height*0.38,0.4),position+inward*(depth*0.98)+V(0,height*0.53,0),rgb(154,217,213),Enum.Material.Glass,"Wedge",CFrame.Angles(0,yaw,0.26))
	end
end

local function cliffEdge(parent,offset,index,startPoint,endPoint,inward,count,seedBase)
	local delta=endPoint-startPoint
	local length=delta.Magnitude
	local width=length/count
	local along=delta*(1/length)
	local yaw=math.abs(along.X)>0.5 and 0 or math.pi/2
	for j=1,count do
		local center=offset+startPoint+along*((j-0.5)*width)
		cliffSegment(parent,center,width,28,57+((j+seedBase)%4)*5,index,j+seedBase,yaw,inward)
	end
end

local function naturalBoundary(parent,offset,index)
	local rim=folder(parent,"NaturalBoundary")
	cliffEdge(rim,offset,index,V(-356,0,-336),V(-356,0,336),V(1,0,0),11,1)
	cliffEdge(rim,offset,index,V(356,0,-336),V(356,0,336),V(-1,0,0),11,7)
	cliffEdge(rim,offset,index,V(-356,0,336),V(356,0,336),V(0,0,-1),12,4)
	if index==1 then
		-- The only opening leads into an enclosed, walkable garden corridor.
		cliffEdge(rim,offset,index,V(-356,0,-336),V(-24,0,-336),V(0,0,1),6,2)
		cliffEdge(rim,offset,index,V(24,0,-336),V(356,0,-336),V(0,0,1),6,8)
	else
		cliffEdge(rim,offset,index,V(-356,0,-336),V(356,0,-336),V(0,0,1),12,2)
	end
	return rim
end

local function gardenBoundary(neighborhood)
	local rim=folder(neighborhood,"GardenEscarpment")
	local zero=V(0,0,0)
	cliffEdge(rim,zero,1,V(-244,0,-801),V(-244,0,-382),V(1,0,0),7,1)
	cliffEdge(rim,zero,1,V(244,0,-801),V(244,0,-382),V(-1,0,0),7,7)
	cliffEdge(rim,zero,1,V(-244,0,-801),V(244,0,-801),V(0,0,1),8,3)
	cliffEdge(rim,zero,1,V(-244,0,-382),V(-24,0,-382),V(0,0,-1),4,4)
	cliffEdge(rim,zero,1,V(24,0,-382),V(244,0,-382),V(0,0,-1),4,8)
	for _,side in {-1,1} do
		cliffSegment(rim,V(side*34,0,-359),46,16,44,1,3,math.pi/2,V(-side,0,0))
	end
	-- A high stone lintel frames the open bridge without obstructing R6 rigs.
	part(rim,"GardenRockArch",V(61,10,24),V(0,35,-335),rgb(153,166,143),Enum.Material.Rock,"Wedge",CFrame.Angles(0,0,0))
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
	local cluster=folder(parent,"FacetedCrystalCluster")
	local base=detail(cluster,"CrystalMatrix",V(7.3,1.3,6.6)*scale,position+V(0,0.15,0),rgb(93,127,140),Enum.Material.Slate,Enum.PartType.Ball)
	for j=1,4 do
		local a=j*math.pi/2+0.22
		local h=(j%2==0 and 7 or 4.5)*scale
		local w=1.8*scale
		local pos=position+V(math.sin(a)*1.65*scale,h/2,math.cos(a)*1.65*scale)
		local stem=detail(cluster,"CrystalPrism",V(w,h,w),pos,tint,Enum.Material.Glass,nil,CFrame.Angles(0,a,0))
		stem.Transparency=0.12
		-- Paired sloping planes make a clean mineral termination, rather than a
		-- blunt neon cube. Opaque faces retain color against the pale ground.
		for _,side in {-1,1} do
			detail(cluster,"CutCrystalTip",V(w/2,w*1.05,w),pos+V(math.cos(a)*side*w/4,h/2+w*0.52,-math.sin(a)*side*w/4),tint:Lerp(P.cream,side==1 and 0.2 or 0.05),Enum.Material.SmoothPlastic,"Wedge",CFrame.Angles(0,a+side*math.pi/2,0))
		end
		detail(cluster,"CrystalFaceReflection",V(w*0.12,h*0.76,0.035),pos+V(math.sin(a)*(w/2+0.025),h*0.03,math.cos(a)*(w/2+0.025)),tint:Lerp(P.cream,0.65),Enum.Material.SmoothPlastic,nil,CFrame.Angles(0,a,0))
	end
	return base
end

local function crystalCove(parent,position)
	local cove=folder(parent,"MoonbloomTidalCove")
	detail(cove,"CoveShingle",V(91,1.1,94),position+V(0,0.15,0),rgb(151,190,185),Enum.Material.Pebble,Enum.PartType.Ball)
	local water=detail(cove,"ShelteredCoveWater",V(74,0.24,77),position+V(0,0.85,0),rgb(81,179,188),Enum.Material.Glass,Enum.PartType.Ball)
	water.Transparency=0.19
	for j=1,12 do
		local a=j*math.pi*2/12
		local pos=position+V(math.sin(a)*38,1.0,math.cos(a)*39)
		detail(cove,"CoveShoreBoulder",V(12,6+(j%3),10),pos,rgb(110,155,164),Enum.Material.Slate,Enum.PartType.Ball,CFrame.Angles(0,a,0))
		if j%2==0 then crystalCluster(cove,pos+V(0,2,0),0.8+(j%3)*0.2,j%4==0 and rgb(176,166,220) or rgb(137,218,212)) end
	end
	for j=1,5 do
		local x=-18+j*7
		detail(cove,"SubmergedCrystal",V(3,0.12,4),position+V(x,1.0,8+(j%2)*11),rgb(169,218,211),Enum.Material.Neon,nil,CFrame.Angles(0,j*0.8,0))
	end
	local pier=folder(cove,"CoveViewingPier")
	for j=0,7 do part(pier,"BleachedBoardwalkPlank",V(12,0.35,2.8),position+V(0,1.55,39-j*2.8),rgb(191,198,184),Enum.Material.WoodPlanks) end
	for _,x in {-5.5,5.5} do
		for _,z in {20,38} do part(pier,"PierMooringPost",V(0.65,4.4,0.65),position+V(x,2.0,z),rgb(107,138,136),Enum.Material.Wood) end
		part(pier,"PierHandrail",V(0.3,0.3,19),position+V(x,4.05,29),rgb(191,198,184),Enum.Material.Wood)
	end
	plaque(cove,position+V(-21,4.4,43),"The crystal cove","Moonlit quartz · sheltered turquoise water",P.cream,25)
end

local function observatory(parent,position)
	local place=folder(parent,"MoonwatchObservatory")
	local stone=rgb(132,169,178)
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
	local dome=detail(place,"ObservatoryGlassDome",V(52,22,52),position+V(0,20,0),rgb(136,195,200),Enum.Material.Glass,Enum.PartType.Ball)
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
	plaque(place,position+V(-21,4.5,-29),"Moonwatch observatory","A quiet lookout above the crystal coast",P.cream,23)
end

-- Traversable landforms have flat, supported walking surfaces. Their stair
-- routes rise in small increments instead of asking a classic R6 rig to jump.
local function terrace(parent,name,position,size,top,tint,material,capTint,capMaterial)
	local terrain=folder(parent,name)
	local radius=material==Enum.Material.Sandstone and 8 or math.min(14,size.X*0.18)
	local function roundedLayer(core,height,y,color,surface)
		local first=part(terrain,core and "TerraceCore" or "TerraceTread",V(size.X-radius*2,height,size.Z),position+V(0,y,0),color,surface)
		if not core then first:SetAttribute("WalkableTerrace",true) end
		part(terrain,core and "RoundedTerrainCore" or "RoundedTerrainCap",V(size.X,height,size.Z-radius*2),position+V(0,y,0),color,surface)
		for _,x in {-1,1} do for _,z in {-1,1} do
			part(terrain,core and "RoundedTerrainCore" or "RoundedTerrainCap",V(height,radius*2,radius*2),position+V(x*(size.X/2-radius),y,z*(size.Z/2-radius)),color,surface,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
		end end
	end
	-- The core stops below the half-stud cap. Keeping their upper faces apart
	-- avoids the coplanar flicker that is especially visible on mineral shelves.
	roundedLayer(true,top+3.5,(top-4.5)/2,tint,material)
	roundedLayer(false,0.5,top-0.25,capTint,capMaterial)
	-- Tapered mineral/earth layers give the sides depth without obstructing
	-- the exact walking surface or extending inward over the excavation pit.
	for layer=1,3 do
		local h=top*layer/4
		for _,side in {-1,1} do
			detail(terrain,"ExposedEarthStratum",V(0.7,0.8,size.Z*(0.29+layer*0.09)),position+V(side*(size.X/2+0.05),h,(layer-2)*size.Z*0.14),tint:Lerp(P.cream,0.06+layer*0.045),material,nil,CFrame.Angles(0,0,side*(layer-2)*0.035))
		end
	end
	for j=1,4 do
		local z=-size.Z/2+size.Z*(j-0.5)/4
		for _,side in {-1,1} do
			detail(terrain,"ErodedTerraceFace",V(7,math.max(4,top*0.69),size.Z/4.6),position+V(side*(size.X/2-1.5),top*0.34,z),tint:Lerp(P.darkStone,(j%3)*0.045),material,Enum.PartType.Ball,CFrame.Angles(0,0,(j%2==0 and 1 or -1)*0.08))
		end
	end
	-- An asymmetric rounded lip and matching weathered mass break the front
	-- outline while leaving the stair approach on the other side unobstructed.
	local side=material==Enum.Material.Sandstone and -1 or 1
	local lipRadius=math.min(18,size.X*0.18)
	local lipX=side*size.X*0.38
	part(terrain,"NaturalShelfLip",V(0.5,lipRadius*2,lipRadius*2),position+V(lipX,top-0.25,-size.Z/2+3),capTint,capMaterial,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
	part(terrain,"WeatheredShelfPromontory",V(lipRadius*2,math.max(5,top*1.12),lipRadius*2),position+V(lipX,top*0.43,-size.Z/2+4),tint:Lerp(P.darkStone,0.05),material,Enum.PartType.Ball)
	return terrain
end

local function terraceSteps(parent,name,offset,x,startZ,endZ,startTop,endTop,count,tint,material,wood)
	local route=folder(parent,name)
	route:SetAttribute("StartHeight",startTop)
	route:SetAttribute("EndHeight",endTop)
	local rise=(endTop-startTop)/count
	local run=(endZ-startZ)/count
	for j=1,count do
		local top=startTop+rise*j
		local tread=part(route,"TerrainStep",V(16,top-startTop,run+0.025),offset+V(x,(top+startTop)/2,startZ+(j-0.5)*run),tint,material)
		tread:SetAttribute("TerrainStep",true)
		tread:SetAttribute("StepIndex",j)
		if j==1 or j==count or j%5==0 then
			for _,side in {-1,1} do
				part(route,"TrailRailPost",V(0.5,3.6,0.5),offset+V(x+side*8.5,top+1.8,startZ+(j-0.5)*run),wood and P.darkWood or tint:Lerp(P.darkStone,0.2),wood and Enum.Material.Wood or material)
			end
		end
	end
	local length=math.sqrt((endZ-startZ)^2+(endTop-startTop)^2)
	for _,side in {-1,1} do
		local rail=part(route,"TrailHandrail",V(0.3,0.3,length),offset+V(x+side*8.5,(startTop+endTop)/2+3.4,(startZ+endZ)/2),wood and P.lightWood or tint:Lerp(P.cream,0.26),wood and Enum.Material.Wood or material,nil,CFrame.Angles(-math.atan((endTop-startTop)/(endZ-startZ)),0,0))
		rail.CanTouch=false
	end
	return route
end

local function cascade(parent,name,position,top,bottom,width,tint)
	local fall=folder(parent,name)
	local rock=part(fall,"WaterfallRockLip",V(6,2,width+5),position+V(0,top-0.7,0),rgb(100,124,121),Enum.Material.Slate,Enum.PartType.Ball)
	rock.CanCollide=false
	local curtain=detail(fall,"FallingWater",V(0.28,top-bottom,width),position+V(-2.4,(top+bottom)/2,0),tint,Enum.Material.Glass)
	curtain.Transparency=0.24
	for stripe=1,3 do
		local stream=detail(fall,"WaterfallHighlight",V(0.045,top-bottom,0.16),position+V(-2.57,(top+bottom)/2,(stripe-2)*width*0.28),rgb(201,237,227),Enum.Material.Glass)
		stream.Transparency=0.45
	end
	local pool=detail(fall,"CascadePool",V(18,0.28,width+15),position+V(-8,bottom+0.15,0),tint,Enum.Material.Glass,Enum.PartType.Ball)
	pool.Transparency=0.15
	for j=1,3 do
		local foam=detail(fall,"WaterfallFoam",V(3.8,0.15,1.8),position+V(-3.8-j*2,bottom+0.3,(j%2-0.5)*width*0.34),P.cream,Enum.Material.Glass,Enum.PartType.Ball)
		foam.Transparency=0.38
	end
	return fall
end

local function layeredBiomes(parent,offset,index)
	local biome=folder(parent,"LayeredBiome")
	if index==1 then
		local hills=folder(biome,"CloverHighlands")
		local earth=rgb(120,106,79)
		local grass=rgb(117,159,103)
		terrace(hills,"LowOrchardTerrace",offset+V(255,0,154),V(122,0,252),8.3,earth,Enum.Material.Ground,grass,Enum.Material.Grass)
		terrace(hills,"BrookTerrace",offset+V(260,0,180),V(92,0,180),20.3,earth:Lerp(P.stone,0.15),Enum.Material.Ground,grass:Lerp(P.cream,0.05),Enum.Material.Grass)
		terrace(hills,"CloverLookoutTerrace",offset+V(267,0,214),V(66,0,108),36.3,earth:Lerp(P.stone,0.3),Enum.Material.Rock,grass:Lerp(P.cream,0.1),Enum.Material.Grass)
		terraceSteps(hills,"OrchardApproach",offset,228,-8,28,0.3,8.3,12,P.lightWood,Enum.Material.WoodPlanks,true)
		terraceSteps(hills,"BrookClimb",offset,246,45,90,8.3,20.3,18,P.lightWood,Enum.Material.WoodPlanks,true)
		terraceSteps(hills,"LookoutClimb",offset,268,104,160,20.3,36.3,24,P.lightWood,Enum.Material.WoodPlanks,true)
		for j=1,4 do
			local x=j==1 and 263 or j==3 and 294 or 297
			local pos=offset+V(x,j<=2 and 8.3 or 20.3,j<=2 and 44+j*11 or 100+j*12)
			tree(hills,pos,0.95+(j%2)*0.2,1,rgb(94,145,91),j)
			flowerCluster(hills,pos+V(-7,0,3),rgb(236,205,155))
		end
		tree(hills,offset+V(297,36.3,242),1.1,1,rgb(113,158,98),0.5)
		bench(hills,offset+V(276,36.3,252))
		plaque(hills,offset+V(283,40.5,257),"Clover highlands","Follow the timber trail to the valley lookout",P.cream,25)
		cascade(hills,"UpperBrookCascade",offset+V(215,0,195),20.3,8.3,12,rgb(111,183,180))
		cascade(hills,"LowerBrookCascade",offset+V(194,0,202),8.3,0.3,15,rgb(111,183,180))
		local stream=detail(hills,"MeanderingBrook",V(10,0.2,61),offset+V(204,8.46,184),rgb(111,183,180),Enum.Material.Glass)
		stream.Transparency=0.18
		for j=1,8 do
			local pos=offset+V(197+(j%2)*13,8.5,158+j*6)
			detail(hills,"BrookBankStone",V(3.5,1.6,3.0),pos,rgb(151,164,143),Enum.Material.Slate,Enum.PartType.Ball)
		end
		-- A small timber crossing sits over shallow water on the lower shelf.
		for j=0,6 do part(hills,"BrookBridgePlank",V(18,0.25,2),offset+V(204,9,171+j*1.9),P.lightWood,Enum.Material.WoodPlanks) end
		for j=1,3 do part(hills,"BrookBridgeStep",V(18,0.22,1.5),offset+V(204,8.35+j*0.22,168+j*1.5),P.lightWood,Enum.Material.WoodPlanks) end
		for _,x in {195,213} do lamp(hills,offset+V(x,8.3,188),rgb(255,232,179),true) end
	elseif index==2 then
		local mesas=folder(biome,"SandstoneMesas")
		local stone=rgb(165,103,71)
		local cap=rgb(221,168,114)
		terrace(mesas,"LowerCanyonBench",offset+V(-260,0,151),V(112,0,254),10.3,stone,Enum.Material.Sandstone,cap,Enum.Material.Sandstone)
		terrace(mesas,"ArchiveMesaBench",offset+V(-270,0,185),V(92,0,170),24.3,stone:Lerp(rgb(127,73,58),0.18),Enum.Material.Sandstone,cap:Lerp(P.cream,0.12),Enum.Material.Sandstone)
		terrace(mesas,"SunArchSummit",offset+V(-283,0,225),V(66,0,86),39.3,stone:Lerp(rgb(127,73,58),0.3),Enum.Material.Sandstone,cap:Lerp(P.cream,0.22),Enum.Material.Sandstone)
		terraceSteps(mesas,"CanyonApproach",offset,-228,-21,24,0.3,10.3,15,cap,Enum.Material.Sandstone,false)
		terraceSteps(mesas,"MesaSwitchback",offset,-246,47.5,100,10.3,24.3,21,cap,Enum.Material.Sandstone,false)
		terraceSteps(mesas,"SunSummitClimb",offset,-280,124.5,182,24.3,39.3,23,cap,Enum.Material.Sandstone,false)
		local arch=folder(mesas,"WeatheredMesaArch")
		for _,side in {-1,1} do
			part(arch,"ArchStoneLeg",V(6.2,19,9),offset+V(-283+side*13,48.8,229),stone,Enum.Material.Sandstone,nil,CFrame.Angles(0,side*0.08,side*0.07))
			detail(arch,"ArchErosionLayer",V(7.4,1.4,10),offset+V(-283+side*13,47.3,229),cap,Enum.Material.Sandstone)
			part(arch,"ArchUpperShoulder",V(11,8.5,10),offset+V(-283+side*9,59,229),stone:Lerp(P.cream,0.08),Enum.Material.Sandstone,"Wedge",CFrame.Angles(0,side<0 and 0 or math.pi,side*0.15))
		end
		part(arch,"ArchKeystone",V(12,6.5,10),offset+V(-283,61.8,229),cap,Enum.Material.Sandstone,nil,CFrame.Angles(0,0,0.07))
		plaque(mesas,offset+V(-283,43.3,258),"The red mesa","Ancient layers · a trail above the canyon",P.cream,26)
		for _,pos in {V(-300,10.3,47),V(-286,24.3,117),V(-302,39.3,252)} do
			part(mesas,"MesaCactusStem",V(2.2,7,2.2),offset+pos+V(0,3.5,0),rgb(111,143,98),Enum.Material.Grass,Enum.PartType.Ball)
			for _,side in {-1,1} do part(mesas,"MesaCactusArm",V(2.2,3,1.7),offset+pos+V(side*1.6,3.6+side,0),rgb(111,143,98),Enum.Material.Grass,Enum.PartType.Ball,CFrame.Angles(0,0,side*-0.5)) end
		end
		local camp=folder(biome,"CanyonMiningCamp")
		local p=offset+V(260,0.3,93)
		part(camp,"CanvasCampFloor",V(42,0.22,41),p+V(0,0.12,0),rgb(198,147,101),Enum.Material.Ground)
		for _,side in {-1,1} do
			part(camp,"CanvasTentWing",V(17,0.55,25),p+V(side*7,8,0),rgb(198,151,103),Enum.Material.Fabric,nil,CFrame.Angles(0,0,side*-0.66))
			part(camp,"TentSupport",V(0.6,12.8,0.6),p+V(0,6.4,side*11),P.darkWood,Enum.Material.Wood)
		end
		for j=1,10 do
			part(camp,"MineRailSleeper",V(9,0.32,1.0),p+V(0,0.35,25+j*4),P.darkWood,Enum.Material.WoodPlanks)
		end
		for _,x in {-2.9,2.9} do part(camp,"MineRail",V(0.28,0.45,44),p+V(x,0.5,47),rgb(98,91,81),Enum.Material.Metal) end
		part(camp,"OreCartBed",V(8,2.5,7),p+V(0,3.5,43),rgb(114,103,89),Enum.Material.Metal)
		for _,x in {-4,4} do for _,z in {40.5,45.5} do part(camp,"OreCartWheel",V(0.6,2.2,2.2),p+V(x,1.9,z),P.darkWood,Enum.Material.Metal,Enum.PartType.Cylinder) end end
		for j=1,5 do detail(camp,"ExposedCopperOre",V(2.5,2.2,2.5),p+V((j%3-1)*2,5.4,(j%2)*2+42),rgb(173,125,88),Enum.Material.Rock,Enum.PartType.Ball) end
		crate(camp,p+V(-16,0,-7),1.1);barrel(camp,p+V(16,0,-5))
		plaque(camp,p+V(0,5,-18),"The survey camp","Copper tracks beneath the red mesas",P.cream,24)
	else
		local grotto=folder(biome,"GeodeGrotto")
		local rock=rgb(93,135,151)
		local cap=rgb(160,194,197)
		terrace(grotto,"TidalRockShelf",offset+V(260,0,155),V(112,0,250),6.3,rock,Enum.Material.Slate,cap,Enum.Material.Slate)
		terrace(grotto,"QuartzWaterfallShelf",offset+V(276,0,180),V(68,0,180),18.3,rock:Lerp(rgb(115,104,159),0.22),Enum.Material.Slate,cap:Lerp(P.cream,0.1),Enum.Material.Slate)
		terrace(grotto,"GeodeCaveShelf",offset+V(283,0,229),V(66,0,78),32.3,rock:Lerp(rgb(115,104,159),0.4),Enum.Material.Slate,cap:Lerp(P.cream,0.2),Enum.Material.Slate)
		terraceSteps(grotto,"TidalApproach",offset,228,6,30,0.3,6.3,12,cap,Enum.Material.Slate,false)
		terraceSteps(grotto,"QuartzClimb",offset,264,45,90,6.3,18.3,18,cap,Enum.Material.Slate,false)
		terraceSteps(grotto,"GeodeClimb",offset,280,107.5,160,18.3,32.3,21,cap,Enum.Material.Slate,false)
		local skyBridge=folder(grotto,"GrottoSkyBridge")
		local bridge=part(skyBridge,"BridgeLanding",V(16,0.5,34),offset+V(280,32.05,177),P.lightWood,Enum.Material.WoodPlanks)
		bridge:SetAttribute("WalkableLanding",true)
		for j=1,10 do detail(skyBridge,"SkyBridgeDeckSeam",V(16,0.035,0.12),offset+V(280,32.32,160+j*3),P.darkWood,Enum.Material.Wood) end
		for _,x in {271.5,288.5} do
			part(skyBridge,"SkyBridgeHandrail",V(0.4,0.4,34),offset+V(x,35.7,177),P.lightWood,Enum.Material.Wood)
			for _,z in {161,177,193} do part(skyBridge,"SkyBridgePost",V(0.6,3.4,0.6),offset+V(x,34, z),P.darkWood,Enum.Material.Wood) end
		end
		local cave=folder(grotto,"WalkInCrystalCave")
		for j=1,4 do
			for _,side in {-1,1} do
				part(cave,"GeodeCaveButtress",V(10,25+(j%2)*3,15),offset+V(283+side*26,44.8,190+j*14),rock:Lerp(rgb(123,109,164),(j%3)*0.12),Enum.Material.Rock,Enum.PartType.Ball)
			end
		end
		part(cave,"GeodeBackWall",V(52,30,11),offset+V(283,47.3,252),rock,Enum.Material.Rock,Enum.PartType.Ball)
		for j=1,5 do
			part(cave,"GeodeCaveRoof",V(16,13+(j%2)*3,58),offset+V(249+j*11,61+(j%3)*1.5,223),rock:Lerp(rgb(123,109,164),(j%3)*0.12),Enum.Material.Rock,Enum.PartType.Ball,CFrame.Angles(0,0,(j-3)*0.13))
		end
		for j=1,9 do
			local pos=offset+V(j%2==0 and 263 or 303,32.3,185+j*6)
			crystalCluster(cave,pos,0.75+(j%3)*0.24,j%2==0 and rgb(178,164,222) or rgb(127,216,213))
		end
		local mirror=detail(cave,"GeodeMirrorPool",V(25,0.18,25),offset+V(283,32.48,228),rgb(103,193,202),Enum.Material.Glass,Enum.PartType.Ball)
		mirror.Transparency=0.15
		local heart=detail(cave,"GeodeHeart",V(4,8,4),offset+V(283,39.3,244),rgb(179,163,227),Enum.Material.Neon,"Wedge")
		local light=Instance.new("PointLight");light.Color=rgb(163,207,228);light.Brightness=1.2;light.Range=39;light.Parent=heart
		plaque(grotto,offset+V(283,36.5,175),"The geode grotto","Climb into the heart of the crystal coast",P.cream,27)
		cascade(grotto,"UpperQuartzFalls",offset+V(243,0,201),18.3,6.3,15,rgb(100,193,201))
		cascade(grotto,"LowerQuartzFalls",offset+V(204,0,207),6.3,0.3,18,rgb(100,193,201))
		for _,pos in {V(293,6.3,49),V(300,6.3,75),V(302,18.3,114),V(260,18.3,135),V(301,18.3,151)} do crystalCluster(grotto,offset+pos,1.3,rgb(158,210,221)) end
		for j=1,8 do part(grotto,"MineralViewingDeck",V(21,0.25,2.5),offset+V(213,6.8,227+j*2.4),rgb(192,202,193),Enum.Material.WoodPlanks) end
		for j=1,2 do part(grotto,"ViewingDeckStep",V(21,0.24,2),offset+V(213,6.3+j*0.24,224+j*2),rgb(192,202,193),Enum.Material.WoodPlanks) end
		for _,x in {202.5,223.5} do
			part(grotto,"ViewingDeckRail",V(0.4,0.4,22),offset+V(x,10.1,238),P.cream,Enum.Material.Wood)
			for _,z in {228,248} do part(grotto,"ViewingDeckPost",V(0.6,3.4,0.6),offset+V(x,8.4,z),P.cream,Enum.Material.Wood) end
		end
	end
	return biome
end

local function landscapes(parent,offset,index,rng)
	local vegetation=folder(parent,index==3 and "CrystalGroves" or "Woodland")
	local tints={rgb(99,148,99),rgb(137,155,102),rgb(129,210,205)}
	local function grove(point,scale,seed)
		if index==3 then
			local tint=seed%3==0 and rgb(181,168,220) or seed%3==1 and rgb(130,207,208) or rgb(161,214,224)
			crystalCluster(vegetation,point,scale*2.25,tint)
		else
			tree(vegetation,point,scale,index,tints[index],seed*0.9)
		end
	end
	for j=1,23 do
		local side=j%2==0 and -1 or 1
		local x=side*rng:NextNumber(218,302)
		local z=rng:NextNumber(-298,286)
		if z< -105 then z=60+(j%4)*56 end
		local scale=rng:NextNumber(0.85,1.25)
		-- Raised biomes supply their own vegetation at the correct heights.
		-- Avoid burying random ground-level trees/crystals inside the shelves.
		local onRaisedBiome=z> -25 and ((index==2 and x< -195) or (index~=2 and x>195))
		local inMiningCamp=index==2 and x>220 and x<300 and z>48 and z<178
		if not onRaisedBiome and not inMiningCamp then grove(offset+V(x,0.3,z),scale,j) end
	end
	for j=1,10 do
		local x=-166+(j-1)*37
		local z=-291+(j%3)*5
		-- The personal-garden approach remains open through the meadow rim.
		if index~=1 or math.abs(x)>26 then grove(offset+V(x,0.3,z),0.92+(j%4)*0.095,j+23) end
	end
	for j=1,9 do
		grove(offset+V(-276+(j-1)*69,0.3,302+(j%2)*4),0.91+(j%3)*0.12,j+33)
	end
	local groundMaterial=index==1 and Enum.Material.Grass or index==2 and Enum.Material.Sandstone or Enum.Material.Slate
	for _,x in {-265,-109,111,267} do
		local z=math.abs(x)>200 and 295 or -294
		part(vegetation,"SculptedLandscapeMound",V(57,17,39),offset+V(x,-4.4,z),tints[index]:Lerp(P.darkStone,index==3 and 0.26 or 0.07),groundMaterial,Enum.PartType.Ball)
	end
	for j=1,9 do
		local x=-168+(j-1)*42
		local z=j%2==0 and -264 or 289
		if index~=1 or math.abs(x)>25 then
			for k=-1,1 do
				if index==3 then
					detail(vegetation,"QuartzShingle",V(7,2.6+(k%2)*1.1,6),offset+V(x+k*3.6,0.5,z+(k%2)*2.5),rgb(131,164,175):Lerp(P.cream,(j%3)*0.06),Enum.Material.Slate,Enum.PartType.Ball,CFrame.Angles(0,j*0.7,0))
				else
					detail(vegetation,"WoodlandShrub",V(7,5.4+(k%2)*1.3,7),offset+V(x+k*3.6,1.5,z+(k%2)*2.5),tints[index]:Lerp(P.ink,0.12+(j%2)*0.05),Enum.Material.Grass,Enum.PartType.Ball)
				end
			end
		end
	end
	for j=1,28 do
		local side=j%2==0 and -1 or 1
		local point=offset+V(side*rng:NextNumber(222,315),0.35,rng:NextNumber(-290,290))
		if index==3 then
			for pebble=1,3 do
				detail(vegetation,"PolishedCovePebble",V(1.7,0.7,1.2),point+V((pebble-2)*1.6,0.2,(pebble%2)*1.3),rgb(169,195,197):Lerp(P.cream,(j%3)*0.08),Enum.Material.Pebble,Enum.PartType.Ball,CFrame.Angles(0,j,0))
			end
		else
			for blade=1,3 do
				detail(vegetation,"GrassTuft",V(0.3,1.6+(blade%2)*0.4,1.1),point+V((blade-2)*0.45,0.6,0),tints[index]:Lerp(P.cream,0.12),Enum.Material.Grass,"Wedge",CFrame.Angles(0,j,0.1*(blade-2)))
			end
			if j%3==0 then flowerCluster(vegetation,point,index==1 and rgb(229,202,155) or rgb(220,164,119)) end
		end
	end
	for _,side in {-1,1} do
		part(vegetation,"LandscapedMound",V(64,19,57),offset+V(side*294,-4,-285),tints[index]:Lerp(P.darkStone,index==3 and 0.25 or 0),groundMaterial,Enum.PartType.Ball)
		bench(vegetation,offset+V(side*126,0.3,-171))
		for j=1,12 do
			if side<0 or index==3 or j<12 then part(vegetation,"GardenTrailPaver",V(13.0,0.15,8),offset+V(side*(32+j*14),0.42,-171),P.stone,Enum.Material.Slate,nil,CFrame.Angles(0,(j%2)*0.045,0)) end
		end
		for j=1,3 do
			if side<0 or index==3 then part(vegetation,"LandmarkApproachPaver",V(13,0.15,8),offset+V(side*(200+j*13),0.42,-171),P.stone,Enum.Material.Slate) end
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
		for j=1,3 do part(trails,"CoveApproachPaver",V(11,0.16,9),offset+V(198+j*12,0.44,-164),P.stone,Enum.Material.Slate) end
		for j=1,3 do part(trails,"CovePierEntranceStep",V(12,0.4,2.7),offset+V(235,0.45+j*0.36,-160-j*2.7),rgb(191,198,184),Enum.Material.WoodPlanks) end
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
		crystalCove(landmarks,offset+V(235,0.3,-203))
	end
end

local function centralHub(parent,result)
	local hub=folder(parent,"CloverVillage")
	part(hub,"VillagePlaza",V(200,0.2,104),V(0,0.42,-129),rgb(190,191,158),Enum.Material.Cobblestone)
	part(hub,"PlazaInlay",V(192,0.04,96),V(0,0.54,-129),rgb(210,207,175),Enum.Material.Slate)
	part(hub,"CentralWalkway",V(22,0.2,150),V(0,0.44,-76),rgb(218,211,180),Enum.Material.Cobblestone)
	for _,side in {-1,1} do
		part(hub,"ShopApproach",V(70,0.18,16),V(side*43,0.45,-88),rgb(218,211,180),Enum.Material.Cobblestone)
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
	-- The old rarity showcase is now an open village green, with a clear route
	-- from the shops through the rock arch to the personal gardens.
	local green=folder(hub,"VillageGreen")
	part(green,"GardenNeighborhoodPath",V(18,0.18,148),V(0,0.43,-255),rgb(212,207,175),Enum.Material.Cobblestone)
	for _,side in {-1,1} do
		part(green,"GreenSidePath",V(89,0.15,12),V(side*49,0.42,-225),rgb(212,207,175),Enum.Material.Cobblestone)
		lamp(green,V(side*16,0.3,-260),rgb(255,229,179),false)
		for j=1,4 do flowerCluster(green,V(side*(28+j*16),0.4,-198),rgb(233,205,158)) end
	end
	local gazebo=folder(green,"CloverGazebo")
	local center=V(-68,0.3,-237)
	disk(gazebo,"GazeboStoneBase",center+V(0,0.3,0),19,0.6,P.stone,Enum.Material.Cobblestone)
	disk(gazebo,"GazeboDeck",center+V(0,0.67,0),17.6,0.2,P.lightWood,Enum.Material.WoodPlanks)
	for j=1,6 do
		local a=j*math.pi/3
		part(gazebo,"GazeboColumn",V(0.7,11.6,0.7),center+V(math.sin(a)*15.6,6.4,math.cos(a)*15.6),P.darkWood,Enum.Material.Wood)
	end
	for _,side in {-1,1} do
		part(gazebo,"GazeboRoofSlope",V(22,0.6,38),center+V(side*8.8,14.4,0),rgb(126,157,124),Enum.Material.WoodPlanks,nil,CFrame.Angles(0,0,side*-0.33))
	end
	part(gazebo,"GazeboRidge",V(0.8,0.8,40),center+V(0,17.9,0),P.darkWood,Enum.Material.Wood)
	for j=1,2 do part(gazebo,"GazeboEntryStep",V(15,0.25,2.5),center+V(0,j*0.25,-20+j*2),P.lightWood,Enum.Material.WoodPlanks) end
	bench(gazebo,center+V(-7,0.8,5));bench(gazebo,center+V(5,0.8,5))
	local brook=detail(green,"VillageBrook",V(15,0.22,72),V(68,0.49,-240),rgb(112,179,174),Enum.Material.Glass)
	brook.Transparency=0.2
	for j=1,10 do
		local z=-272+j*6.5
		for _,side in {-1,1} do detail(green,"BrookEdgeStone",V(4,1.3,4.5),V(68+side*8.1,0.65,z),rgb(151,164,143),Enum.Material.Slate,Enum.PartType.Ball) end
	end
	for j=0,12 do part(green,"VillageBrookCrossing",V(2.6,0.25,12),V(51+j*2.7,0.88,-225),P.lightWood,Enum.Material.WoodPlanks) end
	for _,z in {-231.3,-218.7} do
		part(green,"BrookCrossingRail",V(37,0.3,0.3),V(68,3.6,z),P.darkWood,Enum.Material.Wood)
		for _,x in {51,68,85} do part(green,"BrookCrossingPost",V(0.4,2.8,0.4),V(x,2.2,z),P.darkWood,Enum.Material.Wood) end
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
	local ocean=detail(scene,"Ocean",V(4000,3,1600),V(1040,-20,0),rgb(67,137,157),Enum.Material.Glass)
	ocean.Transparency=0.16
	local result={destinations={},pits={}}
	local ids={"Meadow","Dunes","Cosmic"}
	local grass={rgb(117,158,106),rgb(190,145,102),rgb(126,171,174)}
	local sand={rgb(225,211,173),rgb(224,174,119),rgb(195,216,215)}
	local rng=Random.new(74119)
	for index,id in ids do
		local island=Instance.new("Model"); island.Name=id; island.Parent=scene
		local offset=V((index-1)*1040,0,0)
		shoreline(island,offset,index)
		naturalBoundary(island,offset,index)
		local groundMaterial=index==1 and Enum.Material.Grass or index==2 and Enum.Material.Sandstone or Enum.Material.Slate
		-- A lower full-size base plus four surrounding lawns leaves a real
		-- recessed sand basin instead of laying the sand on top of the grass.
		part(island,"Grass",V(700,6,660),offset+V(0,-7,0),grass[index],groundMaterial)
		part(island,"NorthernLawn",V(700,6,320),offset+V(0,-2.7,-170),grass[index],groundMaterial)
		part(island,"SouthernLawn",V(700,6,60),offset+V(0,-2.7,300),grass[index],groundMaterial)
		for _,side in {-1,1} do part(island,"SideLawn",V(190,6,280),offset+V(side*255,-2.7,130),grass[index],groundMaterial) end
		local center,size=digSite(island,offset,sand[index],id)
		result.pits[id]={center=center,size=size}
		result.destinations[id]=CFrame.new(offset+V(0,4,7))*CFrame.Angles(0,math.pi,0)
		part(island,"ExpeditionWalkway",V(22,0.18,146),offset+V(0,0.44,-91),rgb(207,203,170),Enum.Material.Cobblestone)
		local name=config.Worlds[index] and config.Worlds[index].name or id
		plaque(island,offset+V(39,4.3,-26),name,"Choose Dig while standing in the sand",P.cream,24)
		landscapes(island,offset,index,rng)
		layeredBiomes(island,offset,index)
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
	centralHub(scene,result)
	result.gardens=GardenService.build(scene,config)
	gardenBoundary(scene:FindFirstChild("GardenNeighborhood"))
	World.startDayNight()
	return result
end

return World
