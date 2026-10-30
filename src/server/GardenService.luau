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
		part(model,"ShedRoof",V(27,0.8,19),center+V(-34,9.1,-42),DARK,Enum.Material.WoodPlanks)
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
