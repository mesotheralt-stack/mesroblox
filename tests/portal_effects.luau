-- The runner appends the actual PortalEffects LocalScript, then calls the check.
-- Pose math is a planar double; native scene validation checks Roblox CFrames.
local portalTime=0
local frameCalls=0
local angleCalls={}
local function portalSignal()
	local listeners={}
	local event={}
	function event:Connect(fn)
		local item={Connected=true}
		function item:Disconnect() self.Connected=false end
		table.insert(listeners,{fn=fn,item=item})
		return item
	end
	function event:Fire(...)
		for _,entry in table.clone(listeners) do if entry.item.Connected then entry.fn(...) end end
	end
	function event:Count()
		local count=0
		for _,entry in listeners do if entry.item.Connected then count+=1 end end
		return count
	end
	return event
end
local vectorMeta={}
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z,_type="Vector3"},vectorMeta) end
vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__index=function(a,key) if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
local poseMeta={}
local function pose(position,angle) return setmetatable({Position=position,Angle=angle or 0,_type="CFrame"},poseMeta) end
local function rotate(v,angle) return vector(v.X*math.cos(angle)-v.Y*math.sin(angle),v.X*math.sin(angle)+v.Y*math.cos(angle),v.Z) end
poseMeta.__mul=function(a,b) return pose(a.Position+rotate(b.Position,a.Angle),a.Angle+b.Angle) end
function poseMeta.__index(self,key)
	if key=="Inverse" then return function() return pose(rotate(vector(-self.Position.X,-self.Position.Y,-self.Position.Z),-self.Angle),-self.Angle) end end
end
local CFrame={new=function(x,y,z) return pose(type(x)=="table" and x or vector(x or 0,y or 0,z or 0)) end,
	Angles=function(_,_,z) table.insert(angleCalls,z);return pose(vector(0,0,0),z) end}
local typeof=function(value) return type(value)=="table" and value._type or type(value) end
local function portalNode(class,name)
	local item={ClassName=class,Name=name or class,_children={},_attrs={},_signals={},Writes=0}
	function item:IsA(wanted) return wanted==self.ClassName or wanted=="BasePart" and self.ClassName=="Part" end
	function item:FindFirstChild(wanted) for _,child in self._children do if child.Name==wanted then return child end end end
	function item:GetDescendants()
		self.Scans=(self.Scans or 0)+1
		local all={}
		for _,child in self._children do table.insert(all,child);for _,p in child:GetDescendants() do table.insert(all,p) end end
		return all
	end
	function item:GetAttribute(key) return self._attrs[key] end
	function item:GetAttributeChangedSignal(key) self._signals[key]=self._signals[key] or portalSignal();return self._signals[key] end
	function item:SetAttribute(key,value)
		self._attrs[key]=value
		if self._signals[key] then self._signals[key]:Fire() end
	end
	item.DescendantAdded,item.DescendantRemoving=portalSignal(),portalSignal()
	return setmetatable(item,{
		__index=function(self,key) if key=="CFrame" then return rawget(self,"_frame") end end,
		__newindex=function(self,key,value)
			if key=="CFrame" then rawset(self,"_frame",value);rawset(self,"Writes",self.Writes+1)
			else rawset(self,key,value) end
		end,
	})
end
local function link(parent,child) child.Parent=parent;table.insert(parent._children,child) end
local function unlink(parent,child)
	local index=table.find(parent._children,child);if index then table.remove(parent._children,index) end
	child.Parent=nil
end
local world=portalNode("Folder","BrainrotWorld")
local workspace=portalNode("Workspace")
workspace.ChildAdded,workspace.ChildRemoved=portalSignal(),portalSignal()
workspace.CurrentCamera={CFrame=CFrame.new(0,0,0)}
function workspace:GetServerTimeNow() return portalTime end
link(workspace,world)
local function metadata(part,center)
	part:SetAttribute("PortalCenter",center)
	part:SetAttribute("PortalBase",CFrame.new(center+vector(8,0,0)))
	part:SetAttribute("PortalSpin",0.62)
	part:SetAttribute("PortalPulse",0.05)
	part:SetAttribute("PortalAlpha",0.2)
end
local function effect(parent,name,center,late)
	local p=portalNode("Part",name or "SwirlingRibbon")
	p.CFrame=CFrame.new(center+vector(8,0,0));p.Transparency=0.2
	if not late then metadata(p,center) end
	link(parent,p)
	return p
end
local near=effect(world,"SwirlingRibbon",vector(10,12,0))
local far=effect(world,"OrbitingSpark",vector(1040,12,0))
local harmless=portalNode("Part","NormalScenery");link(world,harmless)
local run={RenderStepped=portalSignal()}
local game={GetService=function(_,name) return assert(({Workspace=workspace,RunService=run})[name],name) end}

local function verifyPortalEffects()
	local count=0
	local function check(ok,message) count+=1;assert(ok,message) end
	local function frame(dt,time)
		portalTime=time or portalTime+dt
		frameCalls+=1;run.RenderStepped:Fire(dt)
	end
	local before=near.Writes
	frame(0.01,1)
	check(near.Writes==before,"Portal motion must be capped at thirty updates per second")
	frame(0.04,2)
	check(near.Writes>before,"Nearby spiral should animate")
	local offset=near.CFrame.Position-vector(10,12,0)
	check(math.abs(offset.Magnitude-8)<0.0001,"Spiral rotates around its own gate center")
	check(math.abs(offset.Y)>1,"Spiral should visibly move rather than only pulse")
	check(near.Transparency>=0.08 and near.Transparency<=0.58,"Glow pulse stays gentle and bounded")
	check(far.Writes==1,"Other worlds should not animate at a distance")
	check(next(harmless._signals)==nil,"Ordinary map parts must not get attribute listeners")
	local scans=world.Scans
	frame(0.04,3);frame(0.04,4)
	check(world.Scans==scans,"Animation must not rescan map descendants per frame")
	workspace.CurrentCamera.CFrame=CFrame.new(1040,0,0)
	local frozen=near.Writes
	frame(0.04,5)
	check(far.Writes>1 and near.Writes==frozen,"Distance culling follows the active camera")
	workspace.CurrentCamera.CFrame=CFrame.new(0,0,0)
	local late=effect(world,"VortexHeart",vector(0,12,0),true)
	world.DescendantAdded:Fire(late)
	check(late:GetAttributeChangedSignal("PortalSpin"):Count()==1,"Late metadata needs temporary attribute listeners")
	frame(0.04,6)
	check(late.Writes==1,"Incomplete metadata must not animate invalid transforms")
	metadata(late,vector(0,12,0))
	frame(0.04,7)
	check(late.Writes>1,"Late replicated metadata should start the effect")
	check(late:GetAttributeChangedSignal("PortalSpin"):Count()==0,"Completed metadata must release temporary listeners")
	local removed=effect(world,"SwirlingRibbon",vector(0,12,0),true)
	world.DescendantAdded:Fire(removed);world.DescendantRemoving:Fire(removed);unlink(world,removed)
	check(removed:GetAttributeChangedSignal("PortalSpin"):Count()==0,"Removing pending effects must disconnect listeners")
	world.DescendantRemoving:Fire(late);unlink(world,late)
	local removedWrites=late.Writes
	frame(0.04,8)
	check(late.Writes==removedWrites,"Removed effects must stop receiving transforms")
	local pending=effect(world,"VortexHeart",vector(0,12,0),true);world.DescendantAdded:Fire(pending)
	unlink(workspace,world);workspace.ChildRemoved:Fire(world)
	check(world.DescendantAdded:Count()==0 and pending:GetAttributeChangedSignal("PortalBase"):Count()==0,"Map rebuild cleanup disconnects world and pending listeners")
	local previousWrites=near.Writes
	frame(0.04,9)
	check(near.Writes==previousWrites,"Old world effects must not keep animating")
	local replacement=portalNode("Folder","BrainrotWorld")
	local replacementEffect=effect(replacement,"SwirlingRibbon",vector(0,12,0))
	link(workspace,replacement);workspace.ChildAdded:Fire(replacement)
	frame(0.04,1800000000)
	local epochPosition=replacementEffect.CFrame.Position
	frame(0.04,1800000000.1)
	check((replacementEffect.CFrame.Position-epochPosition).Magnitude>0.1,"Epoch server time must still give smooth motion")
	for _,angle in angleCalls do check(angle>=0 and angle<math.pi*2,"Rotation passed to CFrame must stay in a small phase range") end
	workspace.CurrentCamera=nil
	frame(0.04,1800000001)
	check(true,"A missing camera should safely skip the frame")
	print("PASS actual portal motion client ("..count.." checks: rotation, pulse, culling, late attributes, bounded epoch phase, rebuild cleanup)")
end
