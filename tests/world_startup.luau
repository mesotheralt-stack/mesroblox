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
	assert(lighting.ClockTime == 9, "Lighting cycle must start")
	print("PASS actual map startup with restricted Workspace writes, expanded geometry and no floating pins")
end
