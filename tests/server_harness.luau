-- Minimal deterministic Roblox service doubles. Production server code is executed,
-- never reimplemented. These validate state transitions, not engine integration.
local clock = 1
local scheduled = {}
local realOs = os
local os = {clock=function() return clock end, time=function() return 1700000000 + math.floor(clock) end}
local function resumeThread(thread, ...)
	local ok, seconds = coroutine.resume(thread, ...)
	assert(ok, tostring(seconds))
	if coroutine.status(thread) ~= "dead" then table.insert(scheduled, {thread=thread, due=clock+(tonumber(seconds) or 0)}) end
end
local task = {}
function task.wait(seconds) return coroutine.yield(seconds or 0.03) end
function task.spawn(fn, ...) local thread=coroutine.create(fn); resumeThread(thread, ...); return thread end
function task.delay(seconds, fn, ...) local args=table.pack(...); table.insert(scheduled,{due=clock+seconds, thread=coroutine.create(function() fn(table.unpack(args,1,args.n)) end)}) end
local function advance(seconds)
	local finish = clock + seconds
	while true do
		local selected, earliest = nil, math.huge
		for i, entry in scheduled do if entry.due < earliest then selected,earliest=i,entry.due end end
		if not selected or earliest > finish then break end
		clock=earliest
		local entry=table.remove(scheduled,selected)
		resumeThread(entry.thread)
	end
	clock=finish
end
local function signal()
	local value={listeners={}}
	function value:Connect(fn) table.insert(self.listeners,fn); return {Disconnect=function() end} end
	function value:Fire(...) for _,fn in table.clone(self.listeners) do fn(...) end end
	return value
end
local vectorMeta = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
vectorMeta.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__mul=function(a,b) if type(b)=="number" then return vec(a.X*b,a.Y*b,a.Z*b) end return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__index=function(a,key) if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
local Vector3={new=vec,zero=vec(0,0,0)}
local CFrame={new=function(x,y,z) return type(x)=="table" and x or vec(x or 0,y or 0,z or 0) end}
local UDim2={fromOffset=function() return {} end,fromScale=function() return {} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,key) return key end}) end})
local function node(class,name)
	local result={ClassName=class,Name=name or class,_children={},_events={}}
	function result:FindFirstChild(childName) for _,child in self._children do if child.Name==childName then return child end end return nil end
	function result:WaitForChild(childName) local found=self:FindFirstChild(childName); assert(found,"Missing mocked child "..childName); return found end
	function result:FindFirstChildOfClass(wanted) for _,child in self._children do if child.ClassName==wanted then return child end end end
	function result:FindFirstChildWhichIsA(wanted) return self:FindFirstChildOfClass(wanted) end
	function result:IsA(wanted) return self.ClassName==wanted end
	function result:GetDescendants() return {} end
	function result:GetChildren() return self._children end
	function result:GetAttribute(key) return self._attributes and self._attributes[key] end
	function result:SetAttribute(key,value) self._attributes=self._attributes or {}; self._attributes[key]=value end
	function result:Destroy() self.Destroyed=true end
	function result:PivotTo(frame) self.Frame=frame; if self.Root then self.Root.Position=frame;self.Root.CFrame=frame end end
	function result:FireClient(player,...) self._events[player]=table.pack(...) end
	return setmetatable(result,{__newindex=function(self,key,value)
		if key=="Parent" and value then table.insert(value._children,self) end
		rawset(self,key,value)
	end})
end
local Instance={new=function(class) return node(class) end}
local Players=node("Players")
Players.PlayerAdded=signal(); Players.PlayerRemoving=signal()
function Players:GetPlayers() return {} end
local ReplicatedStorage=node("ReplicatedStorage")
local shared=node("Folder","BrainrotShared");shared.Parent=ReplicatedStorage
for _, name in {"Config","CreatureFactory"} do local item=node("ModuleScript",name);item.Parent=shared end
local workspace=node("Workspace")
local RunService={Heartbeat=signal(), IsStudio=function() return true end}
local records={}
local failures={}
local writes={}
local dataStoreInitFailure=false
local store={}
function store:UpdateAsync(key,callback)
	if failures[key] then error("Mock DataStore outage") end
	local nextValue=callback(records[key])
	if nextValue~=nil then records[key]=nextValue; writes[key]=(writes[key] or 0)+1 end
	return nextValue
end
local guid=0
local HttpService={GenerateGUID=function() guid+=1;return "mock-guid-"..guid end}
local game={JobId="mock-server"}
function game:GetService(name) return ({Players=Players,ReplicatedStorage=ReplicatedStorage,DataStoreService={GetDataStore=function() if dataStoreInitFailure then error("Mock unpublished experience") end; return store end},HttpService=HttpService,RunService=RunService})[name] end
function game:BindToClose(callback) self.OnClose=callback end
local script={Parent=node("Folder")}
for _, name in {"World","DetectorTool"} do local item=node("ModuleScript",name);item.Parent=script.Parent end
local Random={new=function(seed)
	local value=seed or 12345
	local random={}
	local function nextUnit() value=(value*48271)%2147483647;return value/2147483647 end
	function random:NextNumber(a,b) a,b=a or 0,b or 1;return a+(b-a)*nextUnit() end
	function random:NextInteger(a,b) return math.min(b,a+math.floor((b-a+1)*nextUnit())) end
	return random
end}
local map={spawnCFrame=vec(0,5,-80),destinations={Home=vec(0,5,-80),Food=vec(-30,5,-30),Sell=vec(30,5,-30),Gear=vec(60,5,-30),Meadow=vec(0,5,0),Dunes=vec(520,5,0),Cosmic=vec(1040,5,0)},pits={Meadow={center=vec(0,0,0),size=vec(100,3,100)},Dunes={center=vec(520,0,0),size=vec(100,3,100)},Cosmic={center=vec(1040,0,0),size=vec(100,3,100)}}}
local require=function(module)
	if module.Name=="Config" then return Config end
	if module.Name=="World" then return {build=function() return map end} end
	if module.Name=="CreatureFactory" then return {create=function() return node("Model") end} end
	if module.Name=="DetectorTool" then return setmetatable({},{__index=function() return function() end end}) end
	error("Unknown mocked module: "..module.Name)
end
local warnings={}
local warn=function(message) table.insert(warnings,message) end
local function makePlayer(userId)
	local player=node("Player","Player"..userId)
	player.UserId=userId;player.Parent=Players
	player.CharacterAdded=signal()
	player.Character=node("Model")
	local root=node("Part","HumanoidRootPart");root.Position=vec(0,5,-100);root.CFrame=root.Position;root.Parent=player.Character
	local humanoid=node("Humanoid");humanoid.Health=100;humanoid.Parent=player.Character
	player.Character.Root=root
	function player:Kick(message) self.KickMessage=message end
	return player
end
