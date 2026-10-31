-- Six shared-world gardens. Ownership and display choices are server-managed;
-- placing creatures here does not change the collection's passive income.
local GardenService = {}
local V = Vector3.new
local rgb = Color3.fromRGB
local WOOD = rgb(145,110,76)
local DARK = rgb(70,89,72)
local CREAM = rgb(239,229,201)
local STONE = rgb(190,197,169)
local LEAF = rgb(116,164,100)

local function folder(parent,name)
	local object=Instance.new("Folder");object.Name=name;object.Parent=parent;return object
end
local function part(parent,name,size,position,color,material,shape,rotation)
	local object=Instance.new("Part")
	object.Name=name;object.Size=size;object.Position=position;object.Color=color
	object.Material=material or Enum.Material.SmoothPlastic
	object.Anchored=true;object.TopSurface=Enum.SurfaceType.Smooth;object.BottomSurface=Enum.SurfaceType.Smooth
	if shape then object.Shape=shape end
	if rotation then object.CFrame=CFrame.new(position)*rotation end
	object.Parent=parent
	return object
end
local function detail(parent,name,size,position,color,shape,rotation)
	local object=part(parent,name,size,position,color,nil,shape,rotation)
	object.CanCollide=false;object.CanTouch=false;object.CanQuery=false
	return object
end
local function sign(parent,name,position,width,text,tint)
	local board=part(parent,name,V(width,2.5,0.3),position,DARK,Enum.Material.Wood,nil,CFrame.Angles(0,math.pi,0))
	board.CanCollide=false
	local surface=Instance.new("SurfaceGui")
	surface.Name="GardenSign";surface.Face=Enum.NormalId.Front;surface.CanvasSize=Vector2.new(640,96)
	surface.MaxDistance=85;surface.LightInfluence=0.25;surface.Parent=board
	local label=Instance.new("TextLabel")
	label.Name="Text";label.BackgroundTransparency=1;label.Size=UDim2.new(1,-22,1,-8)
	label.Position=UDim2.fromOffset(11,4);label.Font=Enum.Font.BuilderSansMedium
	label.TextSize=30;label.TextColor3=tint or CREAM;label.Text=text;label.TextTruncate=Enum.TextTruncate.AtEnd
	label.Parent=surface
	return label,board
end
local function prompt(target,action,gardenId,slot)
	local object=Instance.new("ProximityPrompt")
	object.ActionText=action;object.ObjectText="Personal garden";object.KeyboardKeyCode=Enum.KeyCode.F
	object.MaxActivationDistance=13;object.RequiresLineOfSight=false;object.HoldDuration=0
	object:SetAttribute("Garden",true);object:SetAttribute("GardenId",gardenId)
	if slot then object:SetAttribute("GardenSlot",slot) end
	object.Parent=target
end
local function lamp(parent,position)
	part(parent,"LanternPost",V(0.65,7.5,0.65),position+V(0,3.75,0),WOOD,Enum.Material.Wood)
	part(parent,"LanternCap",V(2.0,0.35,2.0),position+V(0,8,0),CREAM,Enum.Material.Metal)
	local glass=detail(parent,"LanternGlass",V(1.3,1.5,1.3),position+V(0,7.1,0),rgb(255,224,164))
	glass.Material=Enum.Material.Neon
	local glow=Instance.new("PointLight");glow.Color=glass.Color;glow.Brightness=0.8;glow.Range=28;glow.Parent=glass
end
local function flowers(parent,position,tint)
	for j=1,3 do
		local x=(j-2)*2.2
		detail(parent,"FlowerStem",V(0.12,1.3,0.12),position+V(x,0.65,j%2),LEAF)
		detail(parent,"FlowerBloom",V(1.5,0.5,1.5),position+V(x,1.4,j%2),tint,Enum.PartType.Ball)
		detail(parent,"FlowerHeart",V(0.45,0.22,0.45),position+V(x,1.7,j%2),CREAM,Enum.PartType.Ball)
	end
end
local function fence(parent,position,across,width)
	local size=across and V(width,0.35,0.35) or V(0.35,0.35,width)
	for _,h in {1.7,3.0} do part(parent,"FenceRail",size,position+V(0,h,0),WOOD,Enum.Material.Wood) end
	for _,side in {-1,1} do
		local offset=across and V(side*width/2,0,0) or V(0,0,side*width/2)
		part(parent,"FencePost",V(0.8,3.8,0.8),position+offset+V(0,1.9,0),WOOD,Enum.Material.Wood)
	end
end

-- Small crafted details stay out of the garden's ownership/display machinery.
-- They are inert so visiting another plot never catches a character on a prop.
local function scenic(parent,name,size,position,tint,material,shape,rotation)
	local object=detail(parent,name,size,position,tint,shape,rotation)
	object.Material=material or Enum.Material.SmoothPlastic
	object:SetAttribute("ScenicDetail",true)
	return object
end

local function pottedPlant(parent,position,tint,seed)
	local clay=rgb(182,123,91):Lerp(CREAM,(seed%3)*0.055)
	scenic(parent,"TerracottaPlanter",V(2.3,2.1,2.3),position+V(0,1.05,0),clay,Enum.Material.SmoothPlastic,Enum.PartType.Ball)
	scenic(parent,"PlanterRolledRim",V(0.3,2.45,2.45),position+V(0,1.94,0),clay:Lerp(CREAM,0.16),Enum.Material.SmoothPlastic,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
	scenic(parent,"PlanterSoil",V(0.1,1.96,1.96),position+V(0,2.12,0),rgb(91,76,55),Enum.Material.Ground,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
	for _,side in {-1,1} do
		scenic(parent,"PlanterFoliage",V(1.45,2.25,0.65),position+V(side*0.45,2.9,0),LEAF:Lerp(DARK,0.18+(seed%2)*0.08),Enum.Material.Grass,Enum.PartType.Ball,CFrame.Angles(0,seed*0.6,side*-0.42))
	end
	scenic(parent,"PlanterBloom",V(1.4,0.65,1.4),position+V(0,3.9,0),tint:Lerp(CREAM,0.25),nil,Enum.PartType.Ball)
end

local function gardenCraft(parent,center,tint,id)
	local art=folder(parent,"GardenCraftsmanship")
	local roof=DARK:Lerp(tint,0.13)
	for _,side in {-1,1} do
		local roll=side*-0.29
		scenic(art,"ShedPitchedRoof",V(14.2,0.55,19),center+V(-34+side*6.5,10.7,-42),roof,Enum.Material.WoodPlanks,nil,CFrame.Angles(0,0,roll))
		scenic(art,"ShedGableFascia",V(14.7,0.48,0.48),center+V(-34+side*6.5,10.8,-51.65),CREAM,Enum.Material.Wood,nil,CFrame.Angles(0,0,roll))
		for j=1,3 do
			local x=side*(j*3.4-1.0)
			scenic(art,"ShedRoofShingleCourse",V(0.13,0.15,18.7),center+V(-34+x,13.02-math.abs(x)*math.tan(0.29),-42),roof:Lerp(CREAM,0.16),Enum.Material.WoodPlanks)
		end
	end
	scenic(art,"ShedRidgeCap",V(0.65,0.55,19.8),center+V(-34,12.8,-42),CREAM,Enum.Material.Wood)
	for _,x in {-45.7,-22.3} do for _,z in {-49.4,-34.6} do
		scenic(art,"ShedCornerTimber",V(0.5,8.15,0.5),center+V(x,4.75,z),WOOD,Enum.Material.Wood)
	end end
	for _,x in {-28.3,-23.7} do scenic(art,"ShedWindowUpright",V(0.26,3.6,0.34),center+V(x,5.5,-34.0),CREAM,Enum.Material.Wood) end
	for _,y in {3.8,7.2} do scenic(art,"ShedWindowLintel",V(4.85,0.26,0.34),center+V(-26,y,-34.0),CREAM,Enum.Material.Wood) end
	scenic(art,"ShedWindowMullion",V(0.15,3.2,0.38),center+V(-26,5.5,-33.95),WOOD,Enum.Material.Wood)
	scenic(art,"ShedWindowTransom",V(4.3,0.15,0.38),center+V(-26,5.5,-33.95),WOOD,Enum.Material.Wood)
	scenic(art,"ShedWindowBox",V(5.4,0.95,1.7),center+V(-26,3.3,-33.6),WOOD,Enum.Material.WoodPlanks)
	scenic(art,"WindowBoxSoil",V(4.8,0.12,1.2),center+V(-26,3.81,-33.6),rgb(87,76,56),Enum.Material.Ground)
	for j=-1,1 do
		scenic(art,"WindowBoxLeaves",V(1.6,0.8,1.3),center+V(-26+j*1.5,4.1,-33.6),LEAF:Lerp(DARK,0.12),Enum.Material.Grass,Enum.PartType.Ball)
		scenic(art,"WindowBoxBlossom",V(0.95,0.4,0.95),center+V(-26+j*1.5,4.56,-33.6),tint:Lerp(CREAM,0.3),nil,Enum.PartType.Ball)
	end
	scenic(art,"ShedDoorHandle",V(0.3,0.3,0.25),center+V(-32,4,-34.12),rgb(192,159,94),Enum.Material.Metal,Enum.PartType.Ball)
	for _,y in {2.2,6.1} do scenic(art,"ShedDoorHinge",V(0.75,0.2,0.15),center+V(-36.3,y,-34.15),DARK,Enum.Material.Metal) end
	scenic(art,"ShedSkirting",V(24,0.45,0.35),center+V(-34,1.05,-34.25),CREAM,Enum.Material.Wood)
	for j,position in {V(-48,0.72,-28),V(-18,0.72,-45),V(46,0.72,-26)} do pottedPlant(art,center+position,tint,j+id) end
	for _,side in {-1,1} do
		local shrub=center+V(side*47,0,4)
		scenic(art,"ClippedHydrangea",V(6.2,2.7,5.4),shrub+V(0,1.9,0),LEAF:Lerp(DARK,0.3),Enum.Material.Grass,Enum.PartType.Ball)
		scenic(art,"HydrangeaUpperLeaves",V(4.7,2.6,4.3),shrub+V(side*0.8,2.8,0),LEAF:Lerp(DARK,0.18),Enum.Material.Grass,Enum.PartType.Ball)
		for _,bloom in {-1,1} do scenic(art,"HydrangeaBlossom",V(1.7,0.7,1.6),shrub+V(bloom*1.5,3.7,0.5),tint:Lerp(CREAM,0.4),nil,Enum.PartType.Ball) end
	end
	local can=center+V(-37,3.05,-27)
	scenic(art,"WateringCanBody",V(1.7,1.8,1.3),can+V(0,0.8,0),tint:Lerp(DARK,0.22),Enum.Material.Metal,Enum.PartType.Ball)
	scenic(art,"WateringCanSpout",V(0.35,1.8,0.35),can+V(1.05,1.1,0),tint:Lerp(DARK,0.1),Enum.Material.Metal,nil,CFrame.Angles(0,0,-0.8))
	for _,side in {-1,1} do scenic(art,"WateringCanHandle",V(0.16,1.5,0.16),can+V(side*0.65,1.8,0),DARK,Enum.Material.Metal) end
	scenic(art,"WateringCanHandleTop",V(1.4,0.16,0.16),can+V(0,2.5,0),DARK,Enum.Material.Metal)
	for j=1,2 do scenic(art,"SeedPacket",V(1.1,0.08,1.4),center+V(-32+j*1.35,3.01,-27),j==1 and CREAM or tint,Enum.Material.Fabric,nil,CFrame.Angles(0,j*0.22,0)) end
	for j=1,9 do scenic(art,"GardenPavingJoint",V(12.4,0.022,0.13),center+V(0,0.825,-43+j*9.6),STONE:Lerp(DARK,0.24),Enum.Material.Slate) end
	-- A rose pergola frames the existing bird bath in the back corner, well
	-- away from the six creature display pads and the entrance/spawn corridor.
	for _,x in {24,48} do for _,z in {-54,-30} do
		scenic(art,"RosePergolaPost",V(0.65,11.5,0.65),center+V(x,6.4,z),WOOD,Enum.Material.Wood)
		for j=1,2 do scenic(art,"ClimbingRoseLeaves",V(2.4,2.3,1.2),center+V(x,3+j*3.4,z),LEAF:Lerp(DARK,0.17),Enum.Material.Grass,Enum.PartType.Ball,CFrame.Angles(0,j*0.7,0.25)) end
	end end
	for _,x in {24,48} do scenic(art,"ClimbingRoseBloom",V(1.4,0.6,1.4),center+V(x,8.2,-29.35),tint:Lerp(CREAM,0.3),nil,Enum.PartType.Ball) end
	for _,z in {-54,-30} do scenic(art,"PergolaCrossbeam",V(27,0.7,0.8),center+V(36,12.3,z),CREAM,Enum.Material.Wood) end
	for j=1,5 do scenic(art,"PergolaRafter",V(0.65,0.6,28),center+V(23+j*4.3,12.8,-42),WOOD,Enum.Material.Wood) end
end

function GardenService.build(parent,config)
	local neighborhood=folder(parent,"GardenNeighborhood")
	part(neighborhood,"GardenIslandStone",V(466,13,404),V(0,-8,-585),rgb(128,140,115),Enum.Material.Slate)
	part(neighborhood,"GardenIslandLawn",V(460,6,400),V(0,-2.7,-585),LEAF,Enum.Material.Grass)
	part(neighborhood,"GardenEntranceRoad",V(22,0.18,52),V(0,0.45,-411),STONE,Enum.Material.Cobblestone)
	-- A walkable connection from Meadow's rear edge to the neighborhood.
	local bridge=folder(neighborhood,"NeighborhoodBridge")
	for j=0,18 do
		part(bridge,"BridgePlank",V(18,0.4,3.2),V(0,0.5,-329-j*3.2),WOOD,Enum.Material.WoodPlanks)
		if j%3==0 then
			for _,x in {-9,9} do part(bridge,"BridgePost",V(0.6,4,0.6),V(x,2.6,-329-j*3.2),DARK,Enum.Material.Wood) end
		end
	end
	for _,x in {-9,9} do part(bridge,"BridgeHandrail",V(0.4,0.4,61),V(x,4.5,-358),WOOD,Enum.Material.Wood) end
	for _,x in {-9,9} do
		for j=0,6 do scenic(bridge,"BridgeRopeLashing",V(0.85,0.35,0.85),V(x,3.7,-329-j*9.6),CREAM,Enum.Material.Fabric) end
		for _,z in {-331,-387} do scenic(bridge,"BridgeStoneAbutment",V(4,2.2,5),V(x<0 and -11.5 or 11.5,0.3,z),STONE,Enum.Material.Slate,Enum.PartType.Ball) end
	end
	for _,z in {-425,-590,-750} do
		part(neighborhood,"GardenCrossStreet",V(430,0.2,12),V(0,0.45,z),STONE,Enum.Material.Cobblestone)
	end
	for _,x in {-210,210} do
		part(neighborhood,"GardenBoulevard",V(12,0.2,337),V(x,0.45,-587),STONE,Enum.Material.Cobblestone)
		for _,z in {-424,-587,-750} do lamp(neighborhood,V(x,0.3,z)) end
	end
	local _,entrance=sign(neighborhood,"NeighborhoodSign",V(0,8.2,-399),32,"The personal gardens",CREAM)
	for _,x in {-14,14} do part(neighborhood,"NeighborhoodSignPost",V(0.8,8,0.8),V(x,4.2,-399),WOOD,Enum.Material.Wood) end
	entrance:SetAttribute("GardenEntrance",true)
	local plots={}
	local tints={rgb(204,168,132),rgb(151,185,151),rgb(157,179,197),rgb(188,165,200),rgb(216,190,128),rgb(158,192,184)}
	for id=1,6 do
		local column=(id-1)%3
		local row=math.floor((id-1)/3)
		local center=V((column-1)*140,0,-505-row*160)
		local model=Instance.new("Model");model.Name=string.format("Garden%02d",id);model.Parent=neighborhood
		model:SetAttribute("GardenId",id);model:SetAttribute("OwnerUserId",0)
		part(model,"GardenLawn",V(110,0.22,120),center+V(0,0.53,0),LEAF:Lerp(CREAM,0.05+id*0.012),Enum.Material.Grass)
		for _,side in {-1,1} do
			fence(model,center+V(side*55,0.65,0),false,120)
			fence(model,center+V(side*34,0.65,60),true,42)
		end
		fence(model,center+V(0,0.65,-60),true,110)
		part(model,"GardenPath",V(13,0.16,97),center+V(0,0.73,3),STONE,Enum.Material.Cobblestone)
		part(model,"GateApproach",V(20,0.15,20),center+V(0,0.57,68),STONE,Enum.Material.Cobblestone)
		local gate=part(model,"GardenGateArch",V(27,0.7,1.7),center+V(0,8.9,60),WOOD,Enum.Material.Wood)
		for _,x in {-12,12} do part(model,"GatePost",V(1.0,9.0,1.0),center+V(x,4.9,60),WOOD,Enum.Material.Wood) end
		local ownerSign=sign(model,"OwnershipPlaque",center+V(0,7.1,60.4),24,"Garden "..id.." · Unclaimed",CREAM)
		prompt(gate,"Open garden",id)
		lamp(model,center+V(46,0.6,48))
		-- A small potting shed, water feature and generous flower beds.
		part(model,"PottingShed",V(23,8,15),center+V(-34,4.65,-42),tints[id],Enum.Material.WoodPlanks)
		part(model,"ShedDoor",V(6.0,6.4,0.25),center+V(-34,3.8,-34.35),DARK,Enum.Material.Wood)
		detail(model,"ShedWindow",V(4,3,0.2),center+V(-26,5.5,-34.2),CREAM)
		part(model,"PottingTable",V(13,0.5,5),center+V(-34,2.7,-27),WOOD,Enum.Material.Wood)
		for _,x in {-5,5} do part(model,"TableLeg",V(0.5,2.4,3),center+V(-34+x,1.4,-27),WOOD) end
		local water=part(model,"BirdBath",V(10,0.9,10),center+V(36,2.1,-42),STONE,Enum.Material.Slate,Enum.PartType.Ball)
		part(model,"BathPedestal",V(2.5,2.6,2.5),center+V(36,1.3,-42),STONE,Enum.Material.Marble)
		detail(model,"BirdBathWater",V(8,0.14,8),water.Position+V(0,0.53,0),rgb(132,188,180),Enum.PartType.Ball)
		for _,x in {-42,42} do
			part(model,"RaisedFlowerBed",V(12,0.7,9),center+V(x,1.0,39),WOOD,Enum.Material.WoodPlanks)
			flowers(model,center+V(x,1.35,39),tints[id]:Lerp(CREAM,0.18))
		end
		gardenCraft(model,center,tints[id],id)
		local slots,slotSigns={},{}
		for slot=1,6 do
			local x=((slot-1)%3-1)*29
			local z=slot<=3 and 16 or -14
			local at=center+V(x,0.95,z)
			part(model,"DisplayBorder",V(14,0.32,14),at,STONE,Enum.Material.Slate,Enum.PartType.Ball)
			local pad=part(model,"DisplayPad",V(11.5,0.18,11.5),at+V(0,0.2,0),tints[id]:Lerp(CREAM,0.25),Enum.Material.Slate,Enum.PartType.Ball)
			pad:SetAttribute("GardenId",id);pad:SetAttribute("GardenSlot",slot)
			prompt(pad,"Choose a brainrot",id,slot)
			slots[slot]=CFrame.new(center+V(x,1.28,z))*CFrame.Angles(0,math.pi,0)
			slotSigns[slot]=sign(model,"SlotPlaque",center+V(x,1.8,z+9.0),13,"Display "..slot.." · Empty",CREAM)
		end
		local displays=folder(model,"DisplayedBrainrots")
		plots[id]={id=id,model=model,spawnCFrame=CFrame.new(center+V(0,5,48)),slots=slots,ownerSign=ownerSign,slotSigns=slotSigns,displays=displays}
	end
	return plots
end

function GardenService.new(plots,config,factory)
	local manager={plots=plots,byPlayer={},owners={},rendered={}}
	function manager:getPlot(player) return self.byPlayer[player] end
	function manager:getPlotId(player)
		local plot=self:getPlot(player);return plot and plot.id or nil
	end
	function manager:getSpawnCFrame(player)
		local plot=self:getPlot(player);return plot and plot.spawnCFrame or nil
	end
	function manager:claim(player)
		local current=self:getPlot(player)
		if current then return current.id end
		for id,plot in ipairs(self.plots) do
			if not self.owners[id] then
				self.owners[id]=player;self.byPlayer[player]=plot;self.rendered[id]={}
				plot.model:SetAttribute("OwnerUserId",player.UserId)
				plot.ownerSign.Text=(player.DisplayName or player.Name).."'s garden"
				return id
			end
		end
		return nil
	end
	function manager:release(player)
		local plot=self:getPlot(player)
		if not plot then return end
		self.byPlayer[player]=nil;self.owners[plot.id]=nil;self.rendered[plot.id]=nil
		plot.model:SetAttribute("OwnerUserId",0)
		plot.ownerSign.Text="Garden "..plot.id.." · Unclaimed"
		for _,child in table.clone(plot.displays:GetChildren()) do child:Destroy() end
		for slot,label in ipairs(plot.slotSigns) do label.Text="Display "..slot.." · Empty";label.TextColor3=CREAM end
	end
	function manager:sync(player,brainrots,gardenSlots)
		local plot=self:getPlot(player)
		if not plot then return false end
		local byUID,seen={},{}
		for _,brainrot in ipairs(brainrots or {}) do
			if type(brainrot.uid)=="string" then byUID[brainrot.uid]=brainrot end
		end
		local cache=self.rendered[plot.id] or {};self.rendered[plot.id]=cache
		for slot=1,#plot.slots do
			local uid=type(gardenSlots)=="table" and gardenSlots[slot] or ""
			local brainrot=type(uid)=="string" and byUID[uid] or nil
			local spec=brainrot and config.get(config.Creatures,brainrot.specId)
			if seen[uid] then brainrot=nil;spec=nil end
			if spec then seen[uid]=true end
			local value=brainrot and brainrot.level or 1
			if type(value)~="number" or value~=value or math.abs(value)==math.huge then value=1 end
			local level=math.clamp(math.floor(value),1,config.MaxLevel)
			local variant=config.variant(brainrot and brainrot.variant)
			local displayName=spec and (variant.id=="Normal" and spec.name or variant.name.." "..spec.name)
			local signature=spec and (uid..":"..spec.id..":"..level..":"..variant.id) or ""
			local old=cache[slot]
			if not old or old.signature~=signature then
				if old and old.model then old.model:Destroy() end
				if spec then
					local model=factory.create(spec,0.75+(level-1)*0.0075,variant.id)
					model.Name=displayName;model:SetAttribute("Variant",variant.id);model:SetAttribute("GardenId",plot.id);model:SetAttribute("OwnerUserId",player.UserId);model:SetAttribute("BrainrotUID",uid)
					model:PivotTo(plot.slots[slot]);model.Parent=plot.displays
					plot.slotSigns[slot].Text=displayName.." · Lv "..level
					plot.slotSigns[slot].TextColor3=variant.id=="Normal" and CREAM or variant.accent
					cache[slot]={signature=signature,model=model}
				else
					plot.slotSigns[slot].Text="Display "..slot.." · Empty"
					plot.slotSigns[slot].TextColor3=CREAM
					cache[slot]={signature=""}
				end
			end
		end
		return true
	end
	return manager
end

return GardenService
