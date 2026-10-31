-- Authored scenery pockets give each landscape a lived-in, distinct character.
-- Everything in this module is inert decoration, outside the excavation pits.
local BiomeDetails = {}
local V, A = Vector3.new, CFrame.Angles
local rgb = Color3.fromRGB
local cream, wood = rgb(238,225,192), rgb(134,103,73)
local leaf, stone = rgb(92,139,92), rgb(145,158,139)

local function folder(parent,name)
	local item=Instance.new("Folder");item.Name=name;item.Parent=parent;return item
end
local function piece(parent,name,size,at,color,material,shape,rotation)
	local item=Instance.new(shape=="Wedge" and "WedgePart" or "Part")
	item.Name=name;item.Size=size;item.CFrame=CFrame.new(at)*(rotation or CFrame.new())
	item.Color=color;item.Material=material or Enum.Material.SmoothPlastic
	item.Anchored=true;item.CanCollide=false;item.CanTouch=false;item.CanQuery=false
	item.TopSurface=Enum.SurfaceType.Smooth;item.BottomSurface=Enum.SurfaceType.Smooth
	if shape and shape~="Wedge" then item.Shape=shape end
	if math.min(size.X,size.Y,size.Z)<0.2 then item.CastShadow=false end
	item:SetAttribute("ScenicDetail",true);item.Parent=parent;return item
end
local function orb(parent,name,size,at,color,material)
	return piece(parent,name,size,at,color,material,Enum.PartType.Ball)
end
local function disk(parent,name,at,radius,height,color,material)
	return piece(parent,name,V(height,radius*2,radius*2),at,color,material,Enum.PartType.Cylinder,A(0,0,math.pi/2))
end
local function rod(parent,name,a,b,width,color,material)
	local delta=b-a
	local length=delta.Magnitude
	if length<0.001 then return end
	local up=math.abs(delta.Y/length)>0.98 and V(0,0,1) or V(0,1,0)
	return piece(parent,name,V(width,width,length),(a+b)/2,color,material,nil,CFrame.lookAt(V(0,0,0),delta,up))
end
local function fern(parent,at,scale,tint,yaw)
	local plant=folder(parent,"SculptedFern")
	for j=1,5 do
		local angle=yaw+j*math.pi*2/5
		local length=(2.3+(j%2)*0.55)*scale
		local direction=V(math.cos(angle),0,math.sin(angle))
		local middle=at+direction*length*0.48+V(0,1.4*scale,0)
		local tip=at+direction*length+V(0,0.95*scale,0)
		rod(plant,"FernMidrib",at+V(0,0.12*scale,0),middle,0.07*scale,tint,Enum.Material.Grass)
		rod(plant,"FernTipStem",middle,tip,0.055*scale,tint,Enum.Material.Grass)
		for tier=1,3 do
			local t=0.18+tier*0.21
			local height=t<0.48 and (0.12+1.28*t/0.48) or (1.4-(t-0.48)/0.52*0.45)
			local center=at+direction*length*t+V(0,height*scale,0)
			for side=-1,1,2 do
				local sideways=V(-direction.Z,0,direction.X)*side
				local size=0.95-(tier-1)*0.15
				local blade=orb(plant,"FernLeaflet",V(0.36,0.12,size)*scale,
					center+sideways*size*0.32*scale+direction*size*0.19*scale,tint:Lerp(cream,j*0.025),Enum.Material.Grass)
				blade.CFrame=blade.CFrame*A(-0.12,math.pi/2-angle+side*0.75,side*0.12)
				blade.CastShadow=false
			end
		end
	end
end
local function reeds(parent,at,scale,color)
	for j=1,4 do
		local x,z=(j-2.5)*0.48*scale,(j%2)*0.65*scale
		local h=(2.6+j%3*0.55)*scale
		rod(parent,"WatersideReed",at+V(x,0,z),at+V(x+0.18*scale,h,z),0.09*scale,color,Enum.Material.Grass)
		orb(parent,"ReedSeedhead",V(0.22,0.85,0.22)*scale,at+V(x+0.18*scale,h,z),rgb(150,116,78))
	end
end
local function clayPot(parent,at,scale,tint)
	orb(parent,"GlazedPotBody",V(2.3,2.6,2.3)*scale,at+V(0,1.3,0)*scale,tint,Enum.Material.SmoothPlastic)
	disk(parent,"PotLip",at+V(0,2.45,0)*scale,0.82*scale,0.24*scale,tint:Lerp(cream,0.25),Enum.Material.SmoothPlastic)
	disk(parent,"PotDarkOpening",at+V(0,2.59,0)*scale,0.62*scale,0.045*scale,tint:Lerp(rgb(58,54,52),0.6))
	for j=1,2 do
		local h=0.85+j*0.58
		local radius=1.15*math.sqrt(1-((h-1.3)/1.3)^2)+0.035
		disk(parent,"PaintedPotBand",at+V(0,h,0)*scale,radius*scale,0.12*scale,cream,Enum.Material.SmoothPlastic)
	end
end

local function meadowBrook(parent,o)
	local brook=folder(parent,"WindingValleyBrook")
	local points={V(185,0.53,211),V(186,0.53,155),V(184,0.53,101),V(187,0.53,45),
		V(188,0.53,7),V(198,0.53,-52),V(210,0.53,-104),V(235,0.53,-148)}
	local waterTint,bedTint=rgb(114,176,169),rgb(108,130,111)
	local function underCrossing(z) return z> -142.7 and z< -133.3 end
	local function surface(a,b)
		local delta=b-a
		local length=delta.Magnitude
		if length<0.01 then return end
		local middle=(a+b)/2
		local rotation=CFrame.lookAt(V(0,0,0),delta)
		piece(brook,"BrookPebbleBed",V(8.0,0.13,length+0.25),o+middle-V(0,0.18,0),bedTint,Enum.Material.Pebble,nil,rotation)
		local water=piece(brook,"ValleyBrookWater",V(6.6,0.055,length+0.12),o+middle,waterTint,Enum.Material.Glass,nil,rotation)
		water.Transparency=0.18
	end
	for index=1,#points-1 do
		local a,b=points[index],points[index+1]
		local cuts={0,1}
		for _,z in {-142.7,-133.3} do
			local t=(z-a.Z)/(b.Z-a.Z)
			if t>0 and t<1 then table.insert(cuts,t) end
		end
		table.sort(cuts)
		for n=1,#cuts-1 do
			local start=a+(b-a)*cuts[n]
			local finish=a+(b-a)*cuts[n+1]
			if not underCrossing((start.Z+finish.Z)/2) then surface(start,finish) end
		end
		local delta=b-a
		local normal=V(-delta.Z,0,delta.X)/delta.Magnitude
		for j=1,3 do
			local at=a+delta*(j/4)
			if not underCrossing(at.Z) and math.abs(at.Z+138)>14 then
				for side=-1,1,2 do
					orb(brook,"BrookEdgeCobble",V(1.7,0.65,2.6),o+at+normal*side*4.35+V(0,0.05,0),stone:Lerp(cream,(j%3)*0.045),Enum.Material.Slate)
				end
			end
		end
	end
	for _,at in points do
		if not underCrossing(at.Z) then
			disk(brook,"RoundedBrookBed",o+at-V(0,0.174,0),4.0,0.13,bedTint,Enum.Material.Pebble)
			local water=disk(brook,"RoundedBrookWater",o+at+V(0,0.006,0),3.3,0.055,waterTint,Enum.Material.Glass)
			water.Transparency=0.18
		end
	end
	for _,at in {V(180.8,0.3,182),V(191,0.3,79),V(191,0.3,-9),V(206,0.3,-66)} do
		reeds(brook,o+at,0.85,rgb(113,151,103))
	end
end

local function meadow(parent,o)
	meadowBrook(parent,o)
	local orchard=folder(parent,"OrchardLife")
	-- Honey boxes sit on the existing lower orchard shelf, clear of its stairs.
	for _,p in {V(300,8.3,43),V(301,8.3,61)} do
		local at=o+p
		for tier=1,3 do
			piece(orchard,"BeehiveDrawer",V(3.5,1.2,3.6),at+V(0,0.7+(tier-1)*1.18,0),cream:Lerp(wood,tier*0.06),Enum.Material.WoodPlanks)
			piece(orchard,"BeehiveEntrance",V(1.55,0.16,0.07),at+V(0,0.8+(tier-1)*1.18,-1.84),wood)
		end
		piece(orchard,"HiveRainRoof",V(4.2,0.3,4.3),at+V(0,3.85,0),rgb(128,157,118),Enum.Material.Wood)
		for _,x in {-1.2,1.2} do piece(orchard,"HiveStand",V(0.3,0.7,3),at+V(x,0.25,0),wood,Enum.Material.Wood) end
	end
	for treeIndex,at in {o+V(263,8.3,55),o+V(297,8.3,66),o+V(294,20.3,144),o+V(297,20.3,156)} do
		for j=1,5 do
			local a=j*1.2+treeIndex
			local fruit=at+V(math.cos(a)*5,13+(j%3)*1.4,-4+math.sin(a)*2)
			orb(orchard,"OrchardApple",V(0.9,1.05,0.9),fruit,rgb(215,131+j*3,100),Enum.Material.SmoothPlastic)
			piece(orchard,"AppleLeaf",V(0.55,0.1,0.2),fruit+V(0.15,0.57,0),leaf,Enum.Material.Grass,nil,A(0,0.4,0.3))
		end
	end
	local brook=folder(parent,"BrookBankGarden")
	for _,p in {V(190,0.3,196),V(185,0.3,213),V(209,8.3,158),V(212,8.3,213)} do
		reeds(brook,o+p,0.95,leaf)
		fern(brook,o+p+V(3,0,-3),0.85,rgb(95,146,106),p.Z*0.1)
	end
	-- Moss, exposed roots and a fern understory ground the windmill in its meadow.
	local mill=folder(parent,"MillKitchenGarden")
	for row=1,3 do
		local at=o+V(-287+row*8,0.3,-226)
		piece(mill,"VegetableBedSoil",V(6.4,0.3,14),at+V(0,0.14,0),rgb(112,90,63),Enum.Material.Ground)
		for _,side in {-1,1} do piece(mill,"BedTimberEdge",V(0.28,0.55,14.6),at+V(side*3.4,0.28,0),wood,Enum.Material.Wood) end
		for j=1,4 do
			local center=at+V(0,0.7,-5+j*2.5)
			orb(mill,"CabbageHeart",V(1.5,1.1,1.5),center,rgb(158,180,117),Enum.Material.Grass)
			for _,side in {-1,1} do orb(mill,"CabbageLeaf",V(1.25,0.45,1.5),center+V(side*0.56,-0.22,0.1),leaf:Lerp(cream,0.15),Enum.Material.Grass) end
		end
	end
	for j=1,5 do
		local at=o+V(-267+(j%3)*2.1,0.3+math.floor(j/3)*2.2,-192+(j%2)*2.6)
		orb(mill,"FlourSack",V(2.0,2.4,1.75),at+V(0,1.15,0),rgb(217,204,169),Enum.Material.Fabric)
		piece(mill,"SackTie",V(0.75,0.14,0.65),at+V(0,2.3,0),wood)
	end
	for j=1,6 do
		local at=o+V(-292+(j%2)*9,0.3,-241+j*9)
		orb(mill,"MossyGardenStone",V(3.5,1.5,2.9),at+V(0,0.3,0),stone,Enum.Material.Slate)
		orb(mill,"SoftStoneMoss",V(2.8,0.22,2.5),at+V(0,0.92,0),rgb(125,158,105),Enum.Material.Grass)
	end
	local pond=folder(parent,"WaterlilyNook")
	for j=1,4 do
		local at=o+V(208+j*9,1.48,-175+(j%2)*13)
		disk(pond,"LilyLeaf",at,1.55,0.08,rgb(125,164,105),Enum.Material.Grass)
		for petal=1,5 do
			local a=petal*math.pi*2/5
			orb(pond,"LilyPetal",V(0.85,0.3,0.55),at+V(math.cos(a)*0.42,0.23,math.sin(a)*0.42),rgb(240,218,195))
		end
		orb(pond,"LilyPollen",V(0.38,0.35,0.38),at+V(0,0.38,0),rgb(224,186,111))
	end
	for _,at in {V(268,0.3,-155),V(208,0.3,-190),V(-217,0.3,-228)} do fern(parent,o+at,1.2,leaf,at.X*0.03) end
end

local function cactus(parent,at,height)
	local green=rgb(110,147,113)
	orb(parent,"RibbedCactusBody",V(3.2,height,3.2),at+V(0,height/2,0),green,Enum.Material.Grass)
	for j=1,6 do
		local a=j*math.pi/3
		rod(parent,"CactusVerticalRib",at+V(math.cos(a)*1.35,0.8,math.sin(a)*1.35),
			at+V(math.cos(a)*1.35,height-0.7,math.sin(a)*1.35),0.13,rgb(155,177,129),Enum.Material.Grass)
	end
	for _,side in {-1,1} do
		local joint=at+V(side*2.2,height*0.4,0)
		rod(parent,"CactusBranch",joint-V(side*1.2,0,0),joint,0.9,green,Enum.Material.Grass)
		orb(parent,"CactusRaisedArm",V(1.15,height*0.42,1.15),joint+V(0,height*0.16,0),green,Enum.Material.Grass)
	end
	orb(parent,"CactusFlower",V(1.0,0.45,1.0),at+V(0,height,0),rgb(226,151,137))
end
local function dunes(parent,o)
	local oasis=folder(parent,"OasisWeaversCorner")
	local at=o+V(285,0.3,-192)
	piece(oasis,"WovenOasisRug",V(13,0.12,8),at+V(0,0.1,0),rgb(164,104,79),Enum.Material.Fabric)
	for j=1,7 do
		piece(oasis,"WovenRugStripe",V(0.55,0.025,7.4),at+V(-5+j*1.25,0.176,0),j%2==0 and cream or rgb(94,132,133),Enum.Material.Fabric)
	end
	for _,side in {-1,1} do
		for j=1,7 do rod(oasis,"RugTassel",at+V(-5+j*1.3,0.14,side*4),at+V(-5+j*1.3,0.14,side*4.65),0.09,cream,Enum.Material.Fabric) end
	end
	for j=1,4 do clayPot(oasis,o+V(297+(j%2)*3,0.3,-191-j*4),0.75+j*0.07,j%2==0 and rgb(185,125,91) or rgb(126,157,150)) end
	for _,p in {V(202,0.3,-192),V(259,0.3,-152),V(220,0.3,-203)} do reeds(oasis,o+p,0.9,rgb(141,157,103)) end
	for _,p in {V(-204,0.3,-93),V(-295,0.3,-117),V(304,0.3,207)} do cactus(parent,o+p,7.5+(p.Z%3)) end
	local camp=folder(parent,"SurveyorsWorkplace")
	local center=o+V(260,0.3,93)
	for _,sx in {-1,1} do for _,sz in {-1,1} do
		local start=center+V(sx*13,4.1,sz*10)
		local finish=center+V(sx*21,0.22,sz*18)
		rod(camp,"TentGuyRope",start,finish,0.12,rgb(198,179,137),Enum.Material.Fabric)
		piece(camp,"TentPicket",V(0.24,1.1,0.24),finish,wood,Enum.Material.Wood,nil,A(0,0,sx*0.15))
	end end
	local tableAt=center+V(11,0,1)
	for j=1,3 do piece(camp,"SurveyTablePlank",V(2.0,0.3,7),tableAt+V((j-2)*2.05,3.1,0),wood,Enum.Material.WoodPlanks) end
	for _,x in {-2.3,2.3} do for _,z in {-2.4,2.4} do piece(camp,"SurveyTableLeg",V(0.4,3.1,0.4),tableAt+V(x,1.5,z),rgb(103,83,65),Enum.Material.Wood) end end
	piece(camp,"SurveyMapPaper",V(4.7,0.05,4),tableAt+V(0,3.29,0),cream,Enum.Material.Fabric)
	for j=1,4 do piece(camp,"SurveyMapContours",V(3.3-j*0.45,0.022,0.1),tableAt+V(j%2*0.4,3.33,-1.5+j*0.7),rgb(167,137,101),Enum.Material.Fabric,nil,A(0,j*0.17,0)) end
	for j=1,3 do
		piece(camp,"SampleTray",V(1.45,0.25,2),tableAt+V(-1.6+(j-1)*1.6,3.45,2.2),rgb(177,144,101),Enum.Material.Wood)
		orb(camp,"SortedMineralSample",V(0.75,0.6,0.8),tableAt+V(-1.6+(j-1)*1.6,3.85,2.2),rgb(142+j*9,122+j*6,95+j*4),Enum.Material.Rock)
	end
	rod(camp,"SurveyPickHandle",center+V(-8,0.8,-4),center+V(-8,4.5,-2.8),0.2,wood,Enum.Material.Wood)
	rod(camp,"SurveyPickHead",center+V(-9.4,4.45,-2.8),center+V(-6.6,4.45,-2.8),0.32,rgb(107,104,98),Enum.Material.Metal)
	local fossils=folder(parent,"AmmoniteOutcrops")
	for index,p in {V(-298,0.3,-49),V(-313,10.3,78),V(-305,24.3,145)} do
		local base=o+p
		orb(fossils,"FossilSandstone",V(10.5,7.3,6.4),base+V(0,2.8,0),rgb(199,156,108),Enum.Material.Sandstone)
		piece(fossils,"ExposedFossilFace",V(0.18,5.8,5.8),base+V(0,3.1,-3.23),rgb(209,172,125),Enum.Material.Limestone,Enum.PartType.Cylinder,A(0,math.pi/2,0))
		local previous
		for j=0,13 do
			local angle=j*0.53
			local radius=0.2+j*0.15
			local point=base+V(math.cos(angle)*radius,3.1+math.sin(angle)*radius,-3.36)
			if previous then rod(fossils,"AmmoniteSpiral",previous,point,0.22,cream:Lerp(rgb(183,143,96),index*0.08),Enum.Material.Limestone) end
			previous=point
		end
	end
	local scrub=folder(parent,"DesertUnderstory")
	for _,p in {V(-277,0.3,-74),V(-308,0.3,-105),V(290,0.3,178),V(306,0.3,192),V(-310,10.3,59)} do
		for j=1,5 do
			local a=j*math.pi*2/5
			rod(scrub,"DryAgaveLeaf",o+p,o+p+V(math.cos(a)*2.1,1.0+(j%2)*0.5,math.sin(a)*2.1),0.2,rgb(147,155,116),Enum.Material.Grass)
		end
		orb(scrub,"DesertPebble",V(1.8,0.6,1.2),o+p+V(2.4,0.2,0.8),rgb(186,146,104),Enum.Material.Pebble)
	end
end

local function shell(parent,at,scale,tint,yaw)
	local center=at+V(0,0.17,0)
	for j=1,5 do
		local angle=yaw+(j-3)*0.22
		local tip=center+V(math.sin(angle)*1.8*scale,0.12*scale,math.cos(angle)*1.8*scale)
		local rib=rod(parent,"ScallopShellRib",center,tip,0.48*scale,tint:Lerp(cream,(j%2)*0.2),Enum.Material.Marble)
		if rib then rib.CastShadow=false end
	end
	orb(parent,"ShellHinge",V(0.7,0.32,0.55)*scale,center,tint,Enum.Material.Marble)
end
local function coral(parent,at,scale,tint)
	for j=1,3 do
		local h=(1.5+j*0.5)*scale
		local center=at+V((j-2)*1.1*scale,h,(j%2)*0.6*scale)
		piece(parent,"MoonCoralStalk",V(0.35*scale,h,0.35*scale),center-V(0,h/2,0),tint:Lerp(stone,0.3),Enum.Material.Slate)
		orb(parent,"MoonCoralCap",V(2.3,0.6,1.8)*scale,center,tint,Enum.Material.Marble)
		orb(parent,"CoralPearl",V(0.35,0.25,0.35)*scale,center+V(0,0.35*scale,0),cream,Enum.Material.Glass)
	end
end
local function cove(parent,o)
	local beach=folder(parent,"PearlescentShore")
	for j=1,8 do
		local angle=j*math.pi/4
		local at=o+V(235+math.sin(angle)*43,0.3,-203+math.cos(angle)*43)
		shell(beach,at,0.8+(j%3)*0.15,j%2==0 and rgb(205,181,198) or rgb(194,218,210),angle)
		orb(beach,"SmoothPearlPebble",V(1.6,0.65,1.3),at+V(2,0.2,1.3),rgb(169,196,197),Enum.Material.Marble)
	end
	for _,p in {V(193,0.3,-213),V(264,0.3,-249),V(279,0.3,-177),V(199,0.3,-239)} do
		coral(beach,o+p,1.0,rgb(174,181,215))
	end
	local tide=folder(parent,"TidalGarden")
	for index,p in {V(-251,0.3,68),V(-279,0.3,89),V(-239,0.3,111)} do
		local at=o+p
		orb(tide,"TidepoolMineralBasin",V(22,1.1,17),at+V(0,0.18,0),rgb(118,154,161),Enum.Material.Slate)
		local water=orb(tide,"TidepoolWater",V(17,0.12,12.5),at+V(0,0.79,0),rgb(113,189,192),Enum.Material.Glass)
		water.Transparency=0.18
		for j=1,6 do
			local a=j*math.pi/3
			orb(tide,"TidepoolShingle",V(3.5,1.0,2.8),at+V(math.cos(a)*9,0.6,math.sin(a)*6.7),rgb(150,179+j*2,183),Enum.Material.Pebble)
		end
		coral(tide,at+V(-7,0.6,4),0.8,rgb(158+index*9,176,209))
		shell(tide,at+V(8,0.8,-3),0.85,cream,index)
	end
	-- Ribbons hug the existing cavern walls and ceiling, away from its bridge.
	local geode=folder(parent,"GeodeJewellery")
	local function onBackWall(x,y)
		local profile=math.max(0.05,1-((x-283)/26)^2-((y-47.3)/15)^2)
		return o+V(x,y,252-5.5*math.sqrt(profile)-0.07)
	end
	for j=1,7 do
		local x,y=263+j*5,44+(j%3)*1.5
		local tint=j%2==0 and rgb(174,159,217) or rgb(139,206,209)
		for segment=1,3 do
			rod(geode,"CavernMineralVein",onBackWall(x+(segment-2)*0.35,y-4.5+(segment-1)*3),onBackWall(x+(segment-1)*0.35,y-4.5+segment*3),0.22,tint,Enum.Material.Marble)
		end
		for side=-1,1,2 do
			rod(geode,"VeinBranch",onBackWall(x,y),onBackWall(x+side*2.0,y+2.8),0.18,tint:Lerp(cream,0.2),Enum.Material.Marble)
		end
	end
	for j=1,5 do
		local at=o+V(268+(j%3)*10,56+(j%2),206+j*6.8)
		local tint=j%2==0 and rgb(157,205,214) or rgb(178,164,216)
		piece(geode,"HangingQuartzStem",V(1.2,3.8,1.2),at,tint,Enum.Material.Glass,nil,A(0,j*0.4,0))
		piece(geode,"HangingQuartzTip",V(1.2,1.9,1.2),at-V(0,2.7,0),tint:Lerp(cream,0.18),Enum.Material.Marble,"Wedge",A(math.pi,0,j*0.3))
	end
	local pier=folder(parent,"BleachedPierDetails")
	for _,x in {229.5,240.5} do
		for _,z in {-183,-165} do
			for ring=1,3 do
				local coil=disk(pier,"MooringRopeWrap",o+V(x,2.4+ring*0.17,z),0.43,0.12,rgb(211,213,186),Enum.Material.Fabric)
				coil.CastShadow=false
			end
		end
	end
	for _,p in {V(293,6.3,63),V(301,18.3,124),V(258,18.3,146),V(-266,0.3,130)} do
		coral(parent,o+p,0.9,rgb(168,193,204))
	end
end

function BiomeDetails.build(island,offset,index)
	local root=folder(island,"BiomeDetails")
	root:SetAttribute("WorldTheme",({"OrchardValley","SandstoneSurvey","PearlescentCove"})[index])
	if index==1 then meadow(root,offset)
	elseif index==2 then dunes(root,offset)
	else cove(root,offset) end
	return root
end

return BiomeDetails
