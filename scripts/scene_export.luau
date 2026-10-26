-- Offline scene assembly with real Roblox datatypes and reflected Instances.
-- This is a geometry/build tool, not a replacement for a Studio playtest.
local r = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local V, CF = r.Vector3, r.CFrame
local scales = {}
r.implementMethod("Instance", "WaitForChild", function(p, name)
	local child=assert(p:FindFirstChild(name), p.Name.." missing required child "..name)
	return child
end)
r.implementMethod("Model", "GetScale", function(p) return scales[p] or 1 end)
r.implementMethod("Model", "GetPivot", function(p) return p.PrimaryPart and p.PrimaryPart.CFrame or CF.new() end)
r.implementMethod("Model", "PivotTo", function(p, value)
	local transform=value*p:GetPivot():Inverse()
	for _, part in p:GetDescendants() do if part:IsA("BasePart") then part.CFrame=transform*part.CFrame end end
end)
r.implementMethod("Model", "ScaleTo", function(p, value)
	local ratio=value/(scales[p] or 1)
	local pivot=p:GetPivot()
	for _,part in p:GetDescendants() do
		if part:IsA("BasePart") then
			local relative=pivot:ToObjectSpace(part.CFrame)
			part.Size*=ratio
			part.CFrame=pivot*CF.new(relative.Position*ratio)*relative.Rotation
		end
	end
	scales[p]=value
end)
local place=r.deserializePlace(fs.readFile("build/BrainrotBloom.rbxlx"))
local environment={}
for _,name in {"Vector2","Vector3","CFrame","Color3","UDim","UDim2","Enum","Instance","BrickColor","NumberSequence","NumberSequenceKeypoint","ColorSequence","ColorSequenceKeypoint"} do environment[name]=r[name] end
local task={spawn=function() end,delay=function() end,wait=function() error("Offline scene builders must not wait") end}
environment.Random={new=function(seed)
	local value=math.floor(seed or 74119)%2147483647
	local function unit() value=(value*48271)%2147483647; return value/2147483647 end
	return {NextNumber=function(_,a,b) a,b=a or 0,b or 1;return a+(b-a)*unit() end,
		NextInteger=function(_,a,b) return math.min(b,a+math.floor(unit()*(b-a+1))) end}
end}
environment.task=task
local game={}
function game:GetService(name) return assert(place:FindFirstChildOfClass(name),"Missing service "..name) end
local modules={}
environment.game=game
environment.workspace=game:GetService("Workspace")
environment.require=function(module)
	if modules[module] then return modules[module] end
	local env=table.clone(environment);env.script=module
	local fn=luau.load(module.Source,{environment=env,injectGlobals=true,debugName=module.Name})
	local result=fn();modules[module]=result;return result
end
local shared=game:GetService("ReplicatedStorage"):WaitForChild("BrainrotShared")
local config=environment.require(shared:WaitForChild("Config"))
local factory=environment.require(shared:WaitForChild("CreatureFactory"))
local world=environment.require(game:GetService("ServerScriptService"):WaitForChild("BrainrotServer"):WaitForChild("World"))
local built=world.build(config)
assert(built.pits.Meadow and built.pits.Dunes and built.pits.Cosmic,"Scene is incomplete")
assert(config.MaxPlayers==6 and game:GetService("Players").MaxPlayers==6,"Place must be configured for six players")
-- Avatar type is a place setting. Normal gameplay scripts cannot write this
-- protected property; Rojo serializes it before Studio starts the server.
assert(game:GetService("StarterPlayer").GameSettingsAvatar==r.Enum.GameAvatarType.R6,"Place must force classic R6 avatars")
assert(built.gardens and #built.gardens==6,"Scene must include exactly six personal gardens")
for id,plot in ipairs(built.gardens) do
	assert(plot.id==id and #plot.slots==config.GardenSlots and plot.spawnCFrame,"Every garden needs six displays and a safe spawn")
end
local function validate(model)
	local count=0
	for _,p in model:GetDescendants() do
		if p:IsA("BasePart") then
			count+=1
			for _,n in {p.CFrame:GetComponents()} do
				assert(n==n and math.abs(n)<math.huge,"Non-finite geometry transform in "..p:GetFullName())
			end
			assert(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,"Invalid piece dimensions in "..p:GetFullName())
		end
	end
	return count
end
-- Lune stores Roblox Position and CFrame independently, unlike the engine.
-- World builders assign Position for unrotated pieces; reflect those writes
-- into CFrame before validating, rendering or serializing the offline scene.
for _,p in environment.workspace:GetDescendants() do
	if p:IsA("BasePart") and p.CFrame.Position.Magnitude<0.00001 and p.Position.Magnitude>0.00001 then
		p.CFrame=CF.new(p.Position)*p.CFrame.Rotation
	end
end
for id,pit in built.pits do
	local zone=environment.workspace:WaitForChild("BrainrotWorld"):WaitForChild(id):FindFirstChild("DigZone",true)
	assert(zone and math.abs(zone.CFrame.Position.X-pit.center.X)<0.1 and math.abs(zone.CFrame.Position.Z-pit.center.Z)<0.1,"Offline pit position is not aligned: "..id)
end
local scene=environment.workspace:WaitForChild("BrainrotWorld")
assert(not scene:FindFirstChild("RarityPreviewGrove"),"Public showcase must be removed")
for _,id in {"Meadow","Dunes","Cosmic"} do
	local biome=assert(scene:WaitForChild(id):FindFirstChild("LayeredBiome"),id.." needs its own layered terrain")
	local routes={}
	local solids={}
	for _,piece in biome:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then table.insert(solids,piece) end
		if piece:IsA("BasePart") and piece:GetAttribute("WalkableTerrace")==true then
			local core=assert(piece.Parent:FindFirstChild("TerraceCore"),"Terrace walking surface needs solid support")
			assert(core.CFrame.Position.Y+core.Size.Y/2<=piece.CFrame.Position.Y-piece.Size.Y/2+0.01,"Terrace core must not overlap the walking cap and cause flickering")
		end
		if piece:IsA("BasePart") and piece:GetAttribute("TerrainStep")==true then
			assert(piece.Anchored and piece.CanCollide and piece.Size.X>=10,"Terrain steps must support walking characters")
			routes[piece.Parent]=routes[piece.Parent] or {}
			table.insert(routes[piece.Parent],piece)
		end
	end
	local routeCount=0
	for route,steps in routes do
		routeCount+=1
		table.sort(steps,function(a,b) return a:GetAttribute("StepIndex")<b:GetAttribute("StepIndex") end)
		local previous=route:GetAttribute("StartHeight")
		assert(type(previous)=="number" and type(route:GetAttribute("EndHeight"))=="number","Terrain routes need explicit landing heights")
		for _,step in steps do
			local top=step.CFrame.Position.Y+step.Size.Y/2
			assert(top>previous and top-previous<=0.75,"Terrain stair rises must be walkable: "..step:GetFullName())
			-- Conservative bounds protect the torso/head corridor from scenery.
			local body=step.CFrame.Position+V.new(0,step.Size.Y/2+3.5,0)
			for _,solid in solids do
				if solid~=step then
					local q=solid.CFrame:PointToObjectSpace(body)
					assert(math.abs(q.X)>=solid.Size.X/2+0.8 or math.abs(q.Y)>=solid.Size.Y/2+1.5 or math.abs(q.Z)>=solid.Size.Z/2+0.8,"Scenery blocks a terrain stair: "..solid:GetFullName())
				end
			end
			previous=top
		end
		assert(math.abs(previous-route:GetAttribute("EndHeight"))<0.01,"Terrain stairs must reach the next landing")
	end
	assert(routeCount>=3,id.." must have three connected terrain climbs")
end
-- Include rotated boulders and wedge faces when checking the garden route.
-- Conservative world bounds must leave a twelve-stud-wide walking corridor.
for _,boundary in {scene:WaitForChild("Meadow"):WaitForChild("NaturalBoundary"),scene:WaitForChild("GardenNeighborhood"):WaitForChild("GardenEscarpment")} do
	for _,p in boundary:GetChildren() do
		if p:IsA("BasePart") and p.CanCollide then
			local c={p.CFrame:GetComponents()}
			local x,y,z=p.Size.X/2,p.Size.Y/2,p.Size.Z/2
			local ex=math.abs(c[4])*x+math.abs(c[5])*y+math.abs(c[6])*z
			local ey=math.abs(c[7])*x+math.abs(c[8])*y+math.abs(c[9])*z
			local ez=math.abs(c[10])*x+math.abs(c[11])*y+math.abs(c[12])*z
			if c[2]-ey<9 and c[2]+ey>1 and c[3]-ez< -326 and c[3]+ez> -390 then
				assert(math.abs(c[1])-ex>=6,"Rock boundary obstructs garden bridge: "..p:GetFullName())
			end
		end
	end
end
local mapParts=validate(environment.workspace)
assert(mapParts<6000,"Map exceeds its bounded geometry budget")
for _,spec in config.Creatures do
	local model=factory.create(spec,1)
	local count=validate(model)
	assert(count>=25 and count<=150,"Creature geometry budget invalid: "..spec.id.." / "..count)
	model:Destroy()
end
print("Validated all "..#config.Creatures.." sculptures and "..mapParts.." map pieces using native Roblox datatypes")
-- Save the assembled map into the place so Studio's edit view is useful too.
local output=process.args[1] or "BrainrotBloom.rbxlx"
local editorCamera=environment.workspace:FindFirstChildOfClass("Camera") or r.Instance.new("Camera")
editorCamera.Name="Camera"
editorCamera.CFrame=CF.lookAt(V.new(280,260,-360),V.new(0,0,-10))
editorCamera.Focus=CF.new(0,0,-10)
editorCamera.FieldOfView=65
editorCamera.CameraType=r.Enum.CameraType.Custom
editorCamera.Parent=environment.workspace
environment.workspace.CurrentCamera=editorCamera
-- FontFace is the modern serialized form. Lune's legacy Font migration does
-- not understand BuilderSans enum values, so write the explicit family/weight
-- and omit the obsolete Font tokens. Runtime code still uses BuilderSans.
for _,object in place:GetDescendants() do
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		local name=object.Font.Name
		if string.sub(name,1,11)=="BuilderSans" then
			local weight=name=="BuilderSansBold" and r.Enum.FontWeight.Bold or name=="BuilderSansMedium" and r.Enum.FontWeight.Medium or name=="BuilderSansExtraBold" and r.Enum.FontWeight.ExtraBold or r.Enum.FontWeight.Regular
			object.FontFace=r.Font.new("rbxasset://fonts/families/BuilderSans.json",weight,r.Enum.FontStyle.Normal)
		end
	end
end
local serialized=r.serializePlace(place,"xml"):gsub('[ \t]*<token name="Font">%d+</token>\r?\n',"")
-- Round-trip the finished artifact so serialized migrations fail in the build.
local restored=r.deserializePlace(serialized)
assert(restored:FindFirstChildOfClass("Workspace"):FindFirstChild("BrainrotWorld"),"Baked map did not survive serialization")
assert(restored:FindFirstChildOfClass("StarterPlayer").GameSettingsAvatar==r.Enum.GameAvatarType.R6,"R6 setting did not survive serialization")
fs.writeFile(output,serialized)
print("Baked authored map into "..output)
if process.args[2]~="--geometry" then return end
local function vector(v) return {v.X,v.Y,v.Z} end
local function parts(model)
	local result={}
	local items=model:GetDescendants();table.insert(items,model)
	for _,p in items do
		if p:IsA("BasePart") and p.Transparency<0.98 then
			local shape=p:IsA("WedgePart") and "Wedge" or p:IsA("Part") and p.Shape.Name or "Block"
			table.insert(result,{name=p.Name,shape=shape,size=vector(p.Size),cf={p.CFrame:GetComponents()},color={p.Color.R,p.Color.G,p.Color.B},alpha=1-p.Transparency,material=p.Material.Name})
		end
	end
	return result
end
local geometry={creatures={},worlds={},details={}}
for _,spec in config.Creatures do
	local model=factory.create(spec,1)
	table.insert(geometry.creatures,{id=spec.id,name=spec.name,rarity=spec.rarity,parts=parts(model)})
	model:Destroy()
end
for index,id in {"Meadow","Dunes","Cosmic"} do
	local root=environment.workspace:WaitForChild("BrainrotWorld")
	local island=root:FindFirstChild(id)
	local content=parts(island)
	if index==1 then
		-- The village shops are directly under the world folder.
		for _,child in root:GetChildren() do
			if child.Name~="Meadow" and child.Name~="Dunes" and child.Name~="Cosmic" and child.Name~="Ocean" and child.Name~="GardenNeighborhood" then
				for _,p in parts(child) do table.insert(content,p) end
			end
		end
	end
	table.insert(geometry.worlds,{id=id,name=config.Worlds[index].name,parts=content})
	local biome=island:FindFirstChild("LayeredBiome")
	if biome then
		local focus=id=="Dunes" and biome:FindFirstChild("SandstoneMesas") or biome
		table.insert(geometry.details,{id=id,name=config.Worlds[index].name.." / terrain detail",parts=parts(focus or biome)})
	end
end
local neighborhood=environment.workspace:WaitForChild("BrainrotWorld"):FindFirstChild("GardenNeighborhood")
if neighborhood then geometry.gardens={name="Personal Gardens",parts=parts(neighborhood)} end
fs.writeFile("build/scene-geometry.json",serde.encode("json",geometry))
print("Exported real transformed geometry for "..#config.Creatures.." creatures and three worlds")
