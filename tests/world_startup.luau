-- Run the actual map builder with the Workspace write restriction that caused
-- the Studio startup failure. The action suite substitutes World and missed it.
local originalService = game.GetService
local lighting = node("Lighting")
function game:GetService(name)
	if name == "Workspace" then return workspace end
	if name == "Lighting" then return lighting end
	return originalService(self, name)
end
local originalWrite = getmetatable(workspace).__newindex
getmetatable(workspace).__newindex = function(self, key, value)
	assert(key ~= "FallenPartsDestroyHeight", "The current thread cannot write FallenPartsDestroyHeight (lacking capability PluginOrOpenCloud)")
	originalWrite(self, key, value)
end
local function color(r, g, b)
	return {R=r, G=g, B=b, Lerp=function(self, other, alpha)
		return color(self.R+(other.R-self.R)*alpha, self.G+(other.G-self.G)*alpha, self.B+(other.B-self.B)*alpha)
	end}
end
Color3.fromRGB = function(r,g,b) return color(r/255,g/255,b/255) end
Color3.new = color
CFrame.Angles = function() return vec(0,0,0) end
local Vector2 = {new=function(x,y) return {X=x,Y=y} end}
local UDim = {new=function() return {} end}
UDim2.new = function() return {} end
local originalNew = Instance.new
Instance.new = function(class)
	local object = originalNew(class)
	function object:Clone()
		local copy = Instance.new(self.ClassName)
		for key,value in self do
			if type(value) ~= "function" and key ~= "Parent" and string.sub(key,1,1) ~= "_" then copy[key]=value end
		end
		return copy
	end
	return object
end
local function verifyWorld(World)
	local built = World.build(Config)
	assert(workspace:FindFirstChild("BrainrotWorld"), "Map must be created")
	for _,id in {"Meadow","Dunes","Cosmic"} do
		assert(built.pits[id] and built.destinations[id], "World pit and destination must be ready: "..id)
	end
	for _,id in {"Home","Food","Gear","Sell"} do
		assert(built.destinations[id], "Shop/home destination missing: "..id)
	end
	assert(built.spawnCFrame, "Character spawn must be ready")
	assert(#built.displaySlots == #Config.Rarities, "All rarity previews must be created")
	local checks=0
	local function inspect(object)
		assert(object.ClassName~="BillboardGui","Map signs must not create floating pins")
		if object.Name=="Grass" then
			assert(object.Size.X==700 and object.Size.Z==660,"Island must have four times its original area")
			checks+=1
		end
		for _,child in object:GetChildren() do inspect(child) end
	end
	inspect(workspace:FindFirstChild("BrainrotWorld"))
	assert(checks==3,"Every island must be expanded")
	for id,pit in built.pits do
		assert(pit.size.X==320 and pit.size.Z==280,"Every sand pit must be expanded")
		local frame=built.destinations[id]
		assert(math.abs(frame.X-pit.center.X)<pit.size.X/2 and math.abs(frame.Z-pit.center.Z)<pit.size.Z/2,"Travel must land inside the actual expanded pit")
	end
	assert(built.pits.Dunes.center.X-built.pits.Meadow.center.X==1040,"Expanded islands must remain separate")
	local scene=workspace:FindFirstChild("BrainrotWorld")
	local boundaryChecks=0
	local function covered(intervals,first,last,description)
		table.sort(intervals,function(a,b) return a[1]<b[1] end)
		local edge=first
		for _,range in intervals do
			if range[2]>=first and range[1]<=last then
				assert(range[1]<=edge+0.01,description.." contains an open gap")
				edge=math.max(edge,range[2])
			end
		end
		assert(edge>=last,description.." does not enclose the complete map edge")
		boundaryChecks+=1
	end
	for id,landmark in {Meadow="CloverWindmill",Dunes="SunArchSanctuary",Cosmic="MoonwatchObservatory"} do
		local island=scene:FindFirstChild(id)
		local boundary=island:FindFirstChild("NaturalBoundary")
		assert(boundary,id.." needs a natural rock enclosure")
		local offset=built.pits[id].center.X
		local west,east,front,back={},{},{},{}
		for _,stone in boundary:GetChildren() do
			if stone.Name=="CliffCore" then
				assert(stone.Anchored and stone.CanCollide~=false,"Rock walls need solid collision")
				assert(stone.Position.Y-stone.Size.Y/2<=0 and stone.Position.Y+stone.Size.Y/2>=50,"Cliffs must rise above the ground and normal camera height")
				local x,z=stone.Position.X-offset,stone.Position.Z
				local edge,coordinate
				if math.abs(x+356)<0.01 then edge,coordinate=west,z
				elseif math.abs(x-356)<0.01 then edge,coordinate=east,z
				elseif math.abs(z+336)<0.01 then edge,coordinate=front,x
				elseif math.abs(z-336)<0.01 then edge,coordinate=back,x end
				assert(edge,"Every cliff collision core must remain on the outer rim")
				table.insert(edge,{coordinate-stone.Size.X/2,coordinate+stone.Size.X/2})
			end
		end
		covered(west,-336,336,id.." west cliff")
		covered(east,-336,336,id.." east cliff")
		covered(back,-356,356,id.." rear cliff")
		if id=="Meadow" then
			covered(front,-356,-24,id.." front-left cliff")
			covered(front,24,356,id.." front-right cliff")
			for _,range in front do assert(range[2]< -22 or range[1]>22,"Garden bridge opening must stay walkable") end
		else covered(front,-356,356,id.." front cliff") end
		local portal=island and island:FindFirstChild("WorldTravelPortal")
		assert(portal and not island:FindFirstChild("ReturnPortal"),id.." must have an entrance world-travel portal")
		local veil=portal:FindFirstChild("WorldPortal")
		local travelPrompt=veil and veil:FindFirstChildOfClass("ProximityPrompt")
		assert(travelPrompt and travelPrompt:GetAttribute("WorldTravel")==true,id.." portal must expose the world travel prompt")
		local destination=built.destinations[id]
		assert(math.abs(veil.Position.X-destination.X)<80 and math.abs(veil.Position.Z-destination.Z)<80,id.." portal must be near the world entrance")
		local landmarks=island and island:FindFirstChild("Landmarks")
		assert(landmarks and landmarks:FindFirstChild(landmark),id.." needs its own authored landmark")
		local excavation=island:FindFirstChild("ExcavationSite")
		assert(excavation and excavation:FindFirstChild("WideEntranceStep"),"Recessed sand needs entrance steps")
		assert(excavation:FindFirstChild("DigZone").Position.Y+1.5<island:FindFirstChild("NorthernLawn").Position.Y+3,"Sand basin must sit below the lawn")
	end
	local cosmic=scene:FindFirstChild("Cosmic")
	local crystals=0
	for _,object in cosmic:GetDescendants() do
		assert(object.Name~="MoonPine" and object.Name~="CloverOak" and object.Name~="PalmTree","Crystal cove must use mineral groves instead of trees")
		if object.Name=="FacetedCrystalCluster" then crystals+=1 end
	end
	assert(crystals>=40 and cosmic:FindFirstChild("MoonbloomTidalCove",true),"Cove needs substantial crystal groves and sheltered water")
	assert(cosmic:FindFirstChild("CoveViewingPier",true),"Cove landmark needs its walkable viewing pier")
	local meadowGround=scene:FindFirstChild("Meadow"):FindFirstChild("NorthernLawn")
	local canyonGround=scene:FindFirstChild("Dunes"):FindFirstChild("NorthernLawn")
	local coveGround=cosmic:FindFirstChild("NorthernLawn")
	assert(meadowGround.Material==Enum.Material.Grass and canyonGround.Material==Enum.Material.Sandstone and coveGround.Material==Enum.Material.Slate,"World ground materials must express meadow, canyon and mineral cove")
	assert(meadowGround.Color.G>meadowGround.Color.R and canyonGround.Color.R>canyonGround.Color.G and coveGround.Color.B>coveGround.Color.R,"Each world needs a distinct green, warm or turquoise palette")
	assert(scene:FindFirstChild("CloverVillage"),"Detailed village must exist")
	local neighborhood=scene:FindFirstChild("GardenNeighborhood")
	local escarpment=neighborhood and neighborhood:FindFirstChild("GardenEscarpment")
	assert(escarpment,"Garden neighborhood must have its own continuous rock enclosure")
	local gardenWest,gardenEast,gardenRear,gardenFront={},{},{},{}
	for _,stone in escarpment:GetChildren() do
		if stone.Name=="CliffCore" then
			local x,z=stone.Position.X,stone.Position.Z
			local edge,coordinate
			if math.abs(x+244)<0.01 then edge,coordinate=gardenWest,z
			elseif math.abs(x-244)<0.01 then edge,coordinate=gardenEast,z
			elseif math.abs(z+801)<0.01 then edge,coordinate=gardenRear,x
			elseif math.abs(z+382)<0.01 then edge,coordinate=gardenFront,x
			else
				assert(math.abs(x)==34 and z== -359 and stone.Size.Z/2<math.abs(x)-20,"Bridge corridor cliffs must leave ample character clearance")
			end
			if edge then table.insert(edge,{coordinate-stone.Size.X/2,coordinate+stone.Size.X/2}) end
		end
	end
	covered(gardenWest,-801,-382,"Garden west cliff")
	covered(gardenEast,-801,-382,"Garden east cliff")
	covered(gardenRear,-244,244,"Garden rear cliff")
	covered(gardenFront,-244,-24,"Garden front-left cliff")
	covered(gardenFront,24,244,"Garden front-right cliff")
	for _,range in gardenFront do assert(range[2]< -22 or range[1]>22,"Garden neighborhood entry must remain open") end
	local arch=escarpment:FindFirstChild("GardenRockArch")
	assert(arch and arch.Position.Y-arch.Size.Y/2>12,"Garden arch must clear walking and jumping characters")
	assert(#built.gardens==Config.MaxPlayers and #built.gardens==6,"Map must build exactly six personal gardens")
	for id,plot in ipairs(built.gardens) do
		assert(plot.id==id and #plot.slots==Config.GardenSlots and #plot.slotSigns==6,"Every garden needs six display locations and labels")
		assert(plot.model and plot.ownerSign and plot.displays and plot.spawnCFrame,"Garden build result must be usable by the owner service")
	end
	-- Real GardenService manager: no mocked ownership/cache implementation.
	local created=0
	local factory={create=function(spec,scale) created+=1;local model=node("Model",spec.name);model.AppliedScale=scale;return model end}
	local manager=ActualGardenService.new(built.gardens,Config,factory)
	local owners={}
	for id=1,6 do owners[id]=makePlayer(20000+id);assert(manager:claim(owners[id])==id,"Garden allocator must issue unique plots") end
	assert(manager:claim(owners[1])==1,"Claiming twice must be idempotent")
	assert(manager:claim(makePlayer(20007))==nil,"Seventh plot claim must fail")
	local collection={{uid="alpha",specId="sprout",level=1}}
	assert(manager:sync(owners[1],collection,{"alpha","alpha","foreign"}),"Owner must be able to render its garden")
	local plot=manager:getPlot(owners[1])
	assert(created==1 and #plot.displays:GetChildren()==1,"Duplicate/foreign placement IDs must not render duplicate creatures")
	local first=plot.displays:GetChildren()[1]
	assert(first:GetAttribute("OwnerUserId")==owners[1].UserId and first:GetAttribute("BrainrotUID")=="alpha","Display models must be tied to their real owner and creature")
	manager:sync(owners[1],collection,{"alpha"})
	assert(created==1 and plot.displays:GetChildren()[1]==first,"Unchanged snapshots must retain cached models")
	collection[1].level=20
	manager:sync(owners[1],collection,{"alpha"})
	local grown=plot.displays:GetChildren()[1]
	assert(created==2 and first.Destroyed and grown.AppliedScale>first.AppliedScale,"Feeding must replace the cached model at a larger scale")
	assert(string.find(plot.slotSigns[1].Text,"20",1,true),"Garden plaques must reflect the updated level")
	manager:release(owners[1])
	assert(manager:getPlotId(owners[1])==nil and manager:getSpawnCFrame(owners[1])==nil,"Released owners must lose plot and teleport access")
	assert(#plot.displays:GetChildren()==0 and plot.model:GetAttribute("OwnerUserId")==0,"Released gardens must clear models and ownership")
	assert(manager:claim(owners[1])==1 and #plot.displays:GetChildren()==0,"A reused plot must start empty")
	assert(lighting.ClockTime == 9, "Lighting cycle must start")
	print("PASS actual map startup, "..boundaryChecks.." continuous cliff edges, crystal cove, clear garden approaches, portals, six gardens and display lifecycle")
end
