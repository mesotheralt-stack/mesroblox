-- Headless UI interaction checks. These execute the real LocalScript, but do
-- not simulate rendering, Roblox input routing, or layout engine behavior.
local viewportSize = vec(1280,720,0)
local requests = {}
local searchOutcomes = {false,true}
local uiNodes = {}
local events = {Activated=true,MouseEnter=true,MouseLeave=true,FocusLost=true,InputBegan=true,RenderStepped=true,PromptTriggered=true,OnClientEvent=true}
local dimensionMeta = {}
local function dimensions(xs,xo,ys,yo)
	assert(type(xs or 0)=="number" and type(xo or 0)=="number" and type(ys or 0)=="number" and type(yo or 0)=="number","UDim2 requires numeric components")
	return setmetatable({X={Scale=xs or 0,Offset=xo or 0},Y={Scale=ys or 0,Offset=yo or 0}},dimensionMeta)
end
dimensionMeta.__add=function(a,b) return dimensions(a.X.Scale+b.X.Scale,a.X.Offset+b.X.Offset,a.Y.Scale+b.Y.Scale,a.Y.Offset+b.Y.Offset) end
UDim2.new=dimensions
UDim2.fromOffset=function(x,y) return dimensions(0,x,0,y) end
UDim2.fromScale=function(x,y) return dimensions(x,0,y,0) end
Vector2.zero=vec(0,0,0)
local baseNew=Instance.new
local function descendants(object, output)
	output=output or {}
	for _,child in object:GetChildren() do
		if not child.Destroyed then table.insert(output,child); descendants(child,output) end
	end
	return output
end
Instance.new=function(class)
	local object=baseNew(class)
	function object:IsA(wanted)
		if wanted==self.ClassName then return true end
		return wanted=="GuiObject" and ({Frame=true,ScrollingFrame=true,TextLabel=true,TextButton=true,TextBox=true,ViewportFrame=true})[self.ClassName] or false
	end
	object.Visible=true
	object.CanvasPosition=vec(0,0,0)
	function object:GetPropertyChangedSignal(key)
		self._signals=self._signals or {};self._signals[key]=self._signals[key] or signal();return self._signals[key]
	end
	function object:GetChildren() return table.clone(self._children) end
	function object:GetDescendants() return descendants(self) end
	function object:Destroy()
		self.Destroyed=true
		for _,child in table.clone(self._children) do child:Destroy() end
		if self.Parent then
			local at=table.find(self.Parent._children,self)
			if at then table.remove(self.Parent._children,at) end
		end
	end
	local mt=getmetatable(object)
	mt.__index=function(self,key)
		if events[key] then local event=signal();rawset(self,key,event);return event end
		if key=="AbsoluteSize" then
			if self.ClassName=="ScreenGui" then return viewportSize end
			local parentSize=self.Parent and self.Parent.AbsoluteSize or viewportSize
			local size=rawget(self,"Size")
			return size and vec(parentSize.X*size.X.Scale+size.X.Offset,parentSize.Y*size.Y.Scale+size.Y.Offset,0) or parentSize
		end
	end
	table.insert(uiNodes,object)
	return object
end
local baseRequire=require
local require=function(module)
	if module.Name=="CreatureFactory" then return {create=function() return Instance.new("Model") end} end
	return baseRequire(module)
end
local player=makePlayer(999)
Players.LocalPlayer=player
local gui=node("PlayerGui");gui.Parent=player
local state={coins=10000,income=500,world="Meadow",detector="twig",ownedDetectors={"twig"},unlockedWorlds={"Meadow"},brainrots={},foods={crumb=3},stock={{id="crumb",remaining=24}},rotationEnds=1700000300,discoveryCount=50}
for index=1,50 do
	local spec=Config.Creatures[(index-1)%#Config.Creatures+1]
	table.insert(state.brainrots,{uid="pet-"..index,specId=spec.id,name=spec.name,rarity=spec.rarity,level=index,xp=2,xpNeeded=Config.xpNeeded(index),income=Config.income(spec.id,index),growthBoostUntil=0,incomeBoostUntil=0})
end
state.activeBrainrot=state.brainrots[1].uid
local remoteFolder=node("Folder","BrainrotRemotes");remoteFolder.Parent=ReplicatedStorage
local action=node("RemoteFunction","Action");action.Parent=remoteFolder
function action:InvokeServer(kind,payload)
	table.insert(requests,{kind=kind,payload=payload})
	local result={ok=true,state=state}
	if kind=="StartDig" then
		task.wait(Config.SearchSeconds)
		result.found=table.remove(searchOutcomes,1)
		if result.found then result.dig={id="capture-test",required=6,duration=10,specId="sprout",name="Sproutini Spaghetti",rarity="Common"}
		else result.message="No signal this time. Try another spot in the sand." end
	end
	if kind=="TapDig" then result.taps=6;result.complete=true end
	return result
end
for _,name in {"State","Notify"} do local event=node("RemoteEvent",name);event.OnClientEvent=signal();event.Parent=remoteFolder end
function workspace:GetServerTimeNow() return os.time() end
local input={InputBegan=signal(),TouchEnabled=false}
local prompts={PromptTriggered=signal()}
local rendered={RenderStepped=signal()}
local bindings={}
local actions={BindActionAtPriority=function(_,name,fn) bindings[name]=fn end,UnbindAction=function(_,name) bindings[name]=nil end}
local tween={Create=function(_,object,_info,props) return {Play=function() for key,value in props do object[key]=value end end} end}
local originalService=game.GetService
function game:GetService(name)
	return ({UserInputService=input,ContextActionService=actions,ProximityPromptService=prompts,RunService=rendered,TweenService=tween})[name] or originalService(self,name)
end
local TweenInfo={new=function() return {} end}
task.defer=task.spawn
local function visible(object)
	while object do
		if object.Destroyed or object.Visible==false then return false end
		object=object.Parent
	end
	return true
end
local function click(text)
	for i=#uiNodes,1,-1 do
		local object=uiNodes[i]
		if object.ClassName=="TextButton" and object.Text==text and visible(object) then task.spawn(function() object.Activated:Fire() end); return object end
	end
	error("Visible button not found: "..text)
end
local function textExists(text)
	for _,object in uiNodes do if object.Text==text and visible(object) then return true end end
	return false
end
local function checkClient()
	assert(textExists("Brainrot Bloom"),"HUD must initialize")
	for _,size in {vec(1280,720,0),vec(375,812,0),vec(844,390,0)} do
		viewportSize=size
		local screen
		for _,object in uiNodes do if object.ClassName=="ScreenGui" then screen=object;break end end
		screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
		click(size.X<500 and "Bag" or "Collection")
		assert(textExists("Your collection"),"Collection must open")
		local previews=0
		for _,object in uiNodes do if object.ClassName=="ViewportFrame" and visible(object) then previews+=1 end end
		assert(previews==12,"Pagination must limit visible models to twelve, got "..previews)
		click("Next");assert(textExists("2 / 5"),"Next collection page must work")
		click("Uncommon");assert(textExists("Uncommon"),"All rarity filters must build valid dimensions")
		click("All");click("Sort: Income");assert(textExists("Sort: Rarity"),"Sort must cycle");click("Sort: Rarity");click("Sort: Level")
		click("Feed & grow");assert(textExists("Feed to grow"),"Creature detail must open")
		click("Feed one");assert(requests[#requests].kind=="Feed" and requests[#requests].payload.quantity==1,"Feed uses selected creature")
		click("×")
		for _,page in {"Food","Gear","Worlds","Sell"} do click(page);click("×") end
		click("Gear");click("Boosts");assert(textExists("2x Growth / $500"),"Gear boost section must work");click("×")
		rendered.RenderStepped:Fire(0.3)
	end
	local function searches()
		local count=0
		for _,request in requests do if request.kind=="StartDig" then count+=1 end end
		return count
	end
	local beforeSearches=searches()
	click("Dig  ·  E")
	assert(textExists("Scanning…"),"The button must visibly stay busy while waiting for a result")
	click("Scanning…")
	assert(searches()==beforeSearches+1,"Clicking again during a scan must not send another request")
	advance(Config.SearchSeconds-0.01)
	assert(textExists("Scanning…") and not textExists("Tap to collect"),"No capture sheet may open before the scan result")
	advance(0.02)
	assert(textExists("Dig  ·  E") and not textExists("Tap to collect"),"An empty scan must reset the button without showing capture controls")
	assert(textExists("No signal this time. Try another spot in the sand."),"An empty scan needs clear feedback")
	click("Dig  ·  E")
	advance(Config.SearchSeconds+0.001)
	assert(textExists("Tap to collect"),"A successful delayed search must open the capture sheet")
	click("Tap to collect")
	assert(not visible((function() for i=#uiNodes,1,-1 do if uiNodes[i].Text=="Tap to collect" then return uiNodes[i] end end end)()),"Completed capture must close")
	print("PASS real client pages at three viewport sizes, collection filtering/pagination, and delayed found/empty searches")
end
