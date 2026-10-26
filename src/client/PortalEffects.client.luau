-- Decorative motion is local: no replicated per-frame transforms or reward logic.
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local entries={}
local pending={}
local observedWorld=nil
local connections={}
local accumulator=0
local animatedNames={SwirlingRibbon=true,OrbitingSpark=true,VortexHeart=true}
local attributes={"PortalSpin","PortalBase","PortalCenter","PortalPulse","PortalAlpha"}

local function stopWaiting(object)
	local listeners=pending[object]
	if not listeners then return end
	for _,connection in listeners do connection:Disconnect() end
	pending[object]=nil
end

local function track(object)
	if not object:IsA("BasePart") or not animatedNames[object.Name] or entries[object] then return end
	local speed=object:GetAttribute("PortalSpin")
	local base=object:GetAttribute("PortalBase")
	local center=object:GetAttribute("PortalCenter")
	local pulse=object:GetAttribute("PortalPulse")
	local alpha=object:GetAttribute("PortalAlpha")
	if type(speed)~="number" or typeof(base)~="CFrame" or typeof(center)~="Vector3" or type(pulse)~="number" or type(alpha)~="number" then
		-- Attributes may replicate after the Instance. Only the three named
		-- effect kinds need temporary listeners, rather than the entire map.
		if not pending[object] then
			local owner=observedWorld
			local listeners={}
			pending[object]=listeners
			for _,attribute in attributes do
				table.insert(listeners,object:GetAttributeChangedSignal(attribute):Connect(function()
					if observedWorld==owner and object.Parent then track(object) end
				end))
			end
		end
		return
	end
	stopWaiting(object)
	entries[object]={speed=speed,base=base,center=center,pulse=pulse,alpha=alpha}
end
local function clear()
	for _,connection in connections do connection:Disconnect() end
	for object in pending do stopWaiting(object) end
	table.clear(connections)
	table.clear(entries)
	observedWorld=nil
end
local function observe(world)
	if world==observedWorld then return end
	clear()
	observedWorld=world
	for _,object in world:GetDescendants() do track(object) end
	table.insert(connections,world.DescendantAdded:Connect(track))
	table.insert(connections,world.DescendantRemoving:Connect(function(object) entries[object]=nil;stopWaiting(object) end))
end
Workspace.ChildAdded:Connect(function(child) if child.Name=="BrainrotWorld" then observe(child) end end)
Workspace.ChildRemoved:Connect(function(child) if child==observedWorld then clear() end end)
local world=Workspace:FindFirstChild("BrainrotWorld")
if world then observe(world) end

RunService.RenderStepped:Connect(function(dt)
	accumulator+=dt
	if accumulator<1/30 then return end
	accumulator=0
	local camera=Workspace.CurrentCamera
	if not camera then return end
	local origin=camera.CFrame.Position
	local time=Workspace:GetServerTimeNow()
	for object,data in entries do
		if object.Parent==nil then entries[object]=nil
		elseif (origin-data.center).Magnitude<=350 then
			local centerFrame=CFrame.new(data.center)
			object.CFrame=centerFrame*CFrame.Angles(0,0,(time*data.speed)%(math.pi*2))*centerFrame:Inverse()*data.base
			object.Transparency=math.clamp(data.alpha+math.sin((time*1.7)%(math.pi*2))*data.pulse,0.08,0.58)
		end
	end
end)
