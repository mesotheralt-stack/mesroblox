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
	for id,landmark in {Meadow="CloverWindmill",Dunes="SunArchSanctuary",Cosmic="MoonwatchObservatory"} do
		local island=scene:FindFirstChild(id)
		local landmarks=island and island:FindFirstChild("Landmarks")
		assert(landmarks and landmarks:FindFirstChild(landmark),id.." needs its own authored landmark")
		local excavation=island:FindFirstChild("ExcavationSite")
		assert(excavation and excavation:FindFirstChild("WideEntranceStep"),"Recessed sand needs entrance steps")
		assert(excavation:FindFirstChild("DigZone").Position.Y+1.5<island:FindFirstChild("NorthernLawn").Position.Y+3,"Sand basin must sit below the lawn")
	end
	assert(scene:FindFirstChild("CloverVillage"),"Detailed village must exist")
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
	print("PASS actual map startup with restricted Workspace writes, expanded geometry, six gardens and real display lifecycle")
end
