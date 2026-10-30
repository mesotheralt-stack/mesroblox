-- Headless UI interaction checks. These execute the real LocalScript, but do
-- not simulate rendering, Roblox input routing, or layout engine behavior.
local viewportSize = vec(1280,720,0)
local requests = {}
local searchOutcomes = {false,true}
local uiNodes = {}
local events = {Activated=true,MouseEnter=true,MouseLeave=true,MouseButton1Down=true,MouseButton1Up=true,FocusLost=true,InputBegan=true,RenderStepped=true,PromptTriggered=true,OnClientEvent=true}
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
		self.Parent=nil
	end
	local mt=getmetatable(object)
	local baseWrite=mt.__newindex
	mt.__newindex=function(self,key,value)
		local previous=key=="Parent" and self.Parent or nil
		baseWrite(self,key,value)
		if key=="Parent" and previous~=value then
			if previous and rawget(previous,"ChildRemoved") then previous.ChildRemoved:Fire(self) end
			if value and rawget(value,"ChildAdded") then value.ChildAdded:Fire(self) end
		end
	end
	local baseSetAttribute=object.SetAttribute
	function object:SetAttribute(key,value)
		local previous=self:GetAttribute(key)
		baseSetAttribute(self,key,value)
		if previous~=value and self._attributeSignals and self._attributeSignals[key] then self._attributeSignals[key]:Fire() end
	end
	function object:GetAttributeChangedSignal(key)
		self._attributeSignals=self._attributeSignals or {}
		self._attributeSignals[key]=self._attributeSignals[key] or signal()
		return self._attributeSignals[key]
	end
	mt.__index=function(self,key)
		if key=="Parent" then return rawget(self,"_parent") end
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
player.CharacterRemoving=signal()
local function prepareCharacter(character)
	character.ChildAdded=signal();character.ChildRemoved=signal()
	character:FindFirstChildOfClass("Humanoid").Died=signal()
end
prepareCharacter(player.Character)
local backpack=Instance.new("Backpack");backpack.Parent=player
local detector=Instance.new("Tool");detector.Name="Tin Twig";detector:SetAttribute("BrainrotDetector",true);detector.Parent=backpack
local gui=node("PlayerGui");gui.Parent=player
local state={coins=10000,income=500,world="Meadow",detector="twig",ownedDetectors={"twig"},unlockedWorlds={"Meadow"},brainrots={},foods={crumb=3},stock={{id="crumb",remaining=24}},rotationEnds=1700000300,discoveryCount=50}
for index=1,50 do
	local spec=Config.Creatures[(index-1)%#Config.Creatures+1]
	table.insert(state.brainrots,{uid="pet-"..index,specId=spec.id,name=spec.name,rarity=spec.rarity,level=index,xp=2,xpNeeded=Config.xpNeeded(index),income=Config.income(spec.id,index),growthBoostUntil=0,incomeBoostUntil=0})
end
state.activeBrainrot=state.brainrots[1].uid
state.discoveredIds={"sprout"};state.uniqueDiscovered=1
state.garden={id=1,slots={"pet-1","","","","",""},capacity=6}
local remoteFolder=node("Folder","BrainrotRemotes");remoteFolder.Parent=ReplicatedStorage
local action=node("RemoteFunction","Action");action.Parent=remoteFolder
function action:InvokeServer(kind,payload)
	table.insert(requests,{kind=kind,payload=payload})
	local result={ok=true,state=state}
	if kind=="GardenAssign" then
		for slot,uid in state.garden.slots do if uid==payload.uid then state.garden.slots[slot]="" end end
		state.garden.slots[payload.slot]=payload.uid
	elseif kind=="GardenClear" then state.garden.slots[payload.slot]="" end
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
local input={InputBegan=signal(),TouchEnabled=false,GetFocusedTextBox=function() return nil end}
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
		local navigation=object:FindFirstChild("NavigationLabel")
		if object.ClassName=="TextButton" and (object.Text==text or object:GetAttribute("ShortcutPage")==text or navigation and navigation.Text==text) and visible(object) then task.spawn(function() object.Activated:Fire() end); return object end
	end
	error("Visible button not found: "..text)
end
local function textExists(text)
	for _,object in uiNodes do if (object.Text==text or object:GetAttribute("ShortcutPage")==text) and visible(object) then return true end end
	return false
end
local function checkClient()
	assert(textExists("Brainrot Bloom"),"HUD must initialize")
	local gameScreen=gui:FindFirstChild("BrainrotBloom")
	local detectorButton=gameScreen:FindFirstChild("DetectorDig")
	local detectorStatus=gameScreen:FindFirstChild("ExpeditionStatus")
	local function controlsShown() return visible(detectorButton) and visible(detectorStatus) end
	local function controlsHidden() return not visible(detectorButton) and not visible(detectorStatus) end
	assert(controlsHidden() and gameScreen:GetAttribute("DetectorEquipped")==false,"Owning a detector in the backpack must not show its HUD")
	local beforeUnequipped=#requests
	input.InputBegan:Fire({KeyCode=Enum.KeyCode.E},false)
	assert(#requests==beforeUnequipped,"E must not request a search without an equipped detector")
	click("Collection");click("×")
	assert(controlsHidden(),"Closing a page while unequipped must keep detector controls hidden")
	local unrelated=Instance.new("Tool");unrelated.Name="Lantern";unrelated.Parent=player.Character
	assert(controlsHidden(),"An unrelated equipped tool must not enable detector controls")
	unrelated:SetAttribute("BrainrotDetector",true)
	assert(controlsShown(),"A detector marker arriving after the tool must enable the HUD")
	unrelated:SetAttribute("BrainrotDetector",false)
	assert(controlsHidden(),"Removing a detector marker must immediately hide its HUD")
	unrelated.Parent=backpack
	detector.Parent=player.Character
	assert(controlsShown() and gameScreen:GetAttribute("DetectorEquipped")==true,"Moving a real detector into the character must show its controls")
	for _,size in {vec(1280,720,0),vec(375,812,0),vec(844,390,0),vec(568,320,0),vec(520,360,0),vec(760,390,0),vec(768,1024,0)} do
		viewportSize=size
		local screen
		for _,object in uiNodes do if object.ClassName=="ScreenGui" then screen=object;break end end
		screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
		assert(screen:GetAttribute("MenuOpen")==false and screen:GetAttribute("Capturing")==false,"Exploration must expose clear input state to sprint")
		local wallet=screen:FindFirstChild("WalletHud")
		local help
		for _,item in screen:GetChildren() do if item.ClassName=="TextButton" and item.Text=="?" then help=item end end
		local walletRight=wallet.Position.X.Offset+wallet.Size.X.Offset
		local helpLeft=size.X+help.Position.X.Offset-help.Size.X.Offset
		assert(walletRight<=helpLeft,"Wallet must leave the help touch target unobstructed")
		local function bounds(object,parentWidth,parentHeight)
			local width=parentWidth*object.Size.X.Scale+object.Size.X.Offset
			local height=parentHeight*object.Size.Y.Scale+object.Size.Y.Offset
			local anchor=object.AnchorPoint or {X=0,Y=0}
			local left=parentWidth*object.Position.X.Scale+object.Position.X.Offset-anchor.X*width
			local top=parentHeight*object.Position.Y.Scale+object.Position.Y.Offset-anchor.Y*height
			return {left=left,top=top,right=left+width,bottom=top+height,width=width,height=height}
		end
		local function separated(a,b)
			return a.right<=b.left or b.right<=a.left or a.bottom<=b.top or b.bottom<=a.top
		end
		local nav=screen:FindFirstChild("NavigationDock")
		local shortcuts=nav:FindFirstChild("JournalShortcuts")
		local navBounds=bounds(nav,size.X,size.Y)
		local walletBounds=bounds(wallet,size.X,size.Y)
		local helpBounds=bounds(help,size.X,size.Y)
		local shortcutBounds=bounds(shortcuts,navBounds.width,navBounds.height)
		assert(nav.AnchorPoint.Y==0.5 and navBounds.left==12,"Navigation must anchor to the left edge around its vertical center")
		assert(navBounds.top>=12 and navBounds.bottom<=size.Y-12 and math.abs((navBounds.top+navBounds.bottom)/2-size.Y/2)<=60,"Left navigation must remain near the middle and fit within the screen")
		assert(separated(navBounds,walletBounds) and separated(navBounds,helpBounds),"The left dock must not overlap wallet or help controls")
		assert(shortcutBounds.left>=6 and shortcutBounds.right<=navBounds.width-6 and shortcutBounds.bottom<=navBounds.height-6,"Index and Garden must belong to the same left dock")
		local compact=size.Y<600 and size.X>=520
		assert(nav:GetAttribute("LayoutColumns")== (compact and 2 or 1),"Short landscapes need a compact dock above the movement controls")
		if compact then assert(navBounds.bottom<=size.Y-120,"Compact navigation must leave the lower-left movement area clear") end
		local targets={}
		for _,name in {"Collection","Food","Sell","Gear","Index","Garden"} do
			local journal=name=="Index" or name=="Garden"
			local target=journal and shortcuts:FindFirstChild(name.."Shortcut") or nav:FindFirstChild(name.."Navigation")
			local targetBounds=bounds(target,journal and shortcutBounds.width or navBounds.width,journal and shortcutBounds.height or navBounds.height)
			assert(targetBounds.width>=44 and targetBounds.height>=44,"Every dock button needs a comfortable touch target")
			local symbol=target:FindFirstChild(journal and "ShortcutIcon" or "NavigationIcon")
			local word=target:FindFirstChild(journal and "ShortcutLabel" or "NavigationLabel")
			assert(target.Text=="" and not target:FindFirstChildOfClass("UIPadding"),"Dock icons and words must not inherit text padding")
			local iconBounds=bounds(symbol,targetBounds.width,targetBounds.height)
			local labelBounds=bounds(word,targetBounds.width,targetBounds.height)
			assert(iconBounds.right+6<=labelBounds.left,"Dock icons must sit to the left of their words with a clear gap")
			assert((iconBounds.top+iconBounds.bottom)/2==(labelBounds.top+labelBounds.bottom)/2,"Dock icons and words must share a vertical center")
			if journal then
				targetBounds.left+=shortcutBounds.left;targetBounds.right+=shortcutBounds.left
				targetBounds.top+=shortcutBounds.top;targetBounds.bottom+=shortcutBounds.top
			end
			assert(targetBounds.left>=6 and targetBounds.right<=navBounds.width-6 and targetBounds.top>=6 and targetBounds.bottom<=navBounds.height-6,"Every dock target must remain inside the dock")
			for _,other in targets do assert(separated(targetBounds,other),"Dock touch targets must not overlap") end
			table.insert(targets,targetBounds)
		end
		local foodTarget=nav:FindFirstChild("FoodNavigation")
		local response=foodTarget:FindFirstChild("InteractionBorder")
		foodTarget.MouseButton1Down:Fire()
		assert(response.Transparency<0.3,"Press feedback should be clear without shrinking the touch target")
		foodTarget.MouseButton1Up:Fire()
		assert(response.Transparency>0.8,"Button feedback must return to its calm resting state")
		local status=screen:FindFirstChild("ExpeditionStatus")
		assert(status.TextStrokeTransparency~=0.45 and status.BackgroundTransparency<0.3,"World and detector text must have a readable status surface")
		click(size.X<900 and "Bag" or "Collection")
		assert(screen:GetAttribute("MenuOpen")==true,"Open pages must suspend sprint")
		assert(controlsHidden(),"Journal pages must hide detector controls even when equipped")
		assert(textExists("Your collection"),"Collection must open")
		local collectionGrid=screen:FindFirstChild("CollectionGrid",true)
		local collectionLayout=collectionGrid:FindFirstChildOfClass("UIGridLayout")
		local cellWidth=collectionGrid.AbsoluteSize.X*collectionLayout.CellSize.X.Scale+collectionLayout.CellSize.X.Offset
		assert(cellWidth>=170,"Sculpture cards need room for names and income instead of tiny phone columns")
		if size.X<440 then assert(collectionGrid:GetAttribute("CardColumns")==1,"Portrait phones should present large individual sculpture cards") end
		local modal=screen:FindFirstChild("JournalPanel",true)
		local modalTitle=modal:FindFirstChild("JournalTitle")
		local titleConstraint=modalTitle:FindFirstChildOfClass("UITextSizeConstraint")
		assert(modalTitle.TextScaled and titleConstraint.MinTextSize>=18,"Long species titles must fit within a readable bounded type scale")
		local modalBounds=bounds(modal,size.X,size.Y)
		assert(not wallet.Visible and not help.Visible and nav.ZIndex<modal.Parent.ZIndex,"Pages must take precedence over exploration controls")
		assert(modalBounds.top>=12 and modalBounds.bottom<=size.Y-12,"Pages must use the available height without clipping their close control")
		local previews=0
		for _,object in uiNodes do if object.ClassName=="ViewportFrame" and visible(object) then previews+=1 end end
		assert(previews==12,"Pagination must limit visible models to twelve, got "..previews)
		click("Next");assert(textExists("2 / 5"),"Next collection page must work")
		click("Uncommon");assert(textExists("Uncommon"),"All rarity filters must build valid dimensions")
		click("All");click("Sort: Income");assert(textExists("Sort: Rarity"),"Sort must cycle");click("Sort: Rarity");click("Sort: Level")
		click("Feed & grow");assert(textExists("Feed to grow"),"Creature detail must open")
		local hero=screen:FindFirstChild("CreatureHero",true)
		if hero:GetAttribute("Stacked") then
			local stageBounds=bounds(hero:FindFirstChild("SculptureStage"),hero.AbsoluteSize.X,hero.AbsoluteSize.Y)
			local levelBounds=bounds(hero:FindFirstChild("HeroLevel"),hero.AbsoluteSize.X,hero.AbsoluteSize.Y)
			assert(stageBounds.width>=200 and levelBounds.top>=stageBounds.bottom+8,"Phone detail stats must sit below a full-width sculpture stage")
		end
		click("Feed one");assert(requests[#requests].kind=="Feed" and requests[#requests].payload.quantity==1,"Feed uses selected creature")
		click("×")
		assert(screen:GetAttribute("MenuOpen")==false,"Closing a page must restore exploration input")
		assert(controlsShown(),"Closing a page must restore controls for the detector still in hand")
		for _,page in {"Food","Gear","Sell"} do click(page);click("×") end
		for _,object in uiNodes do
			assert(object.Destroyed or object.ClassName~="TextButton" or object.Text~="Worlds","World travel must not retain an on-screen Worlds button")
		end
		for _,worldId in {"Meadow","Dunes","Cosmic"} do
			local portal=Instance.new("ProximityPrompt")
			portal:SetAttribute("WorldTravel",true)
			portal:SetAttribute("WorldId",worldId)
			prompts.PromptTriggered:Fire(portal,player)
			assert(textExists("Choose a world"),"Every world portal must open the travel menu")
			if worldId=="Meadow" then
				click("Travel to sand pit")
				assert(requests[#requests].kind=="Teleport" and requests[#requests].payload.destination=="Meadow","Portal menu must travel to an unlocked world through the server")
				assert(not textExists("Choose a world"),"Successful portal travel must close the menu")
			elseif worldId=="Dunes" then
				click("Unlock · $8.0K")
				assert(requests[#requests].kind=="UnlockWorld" and requests[#requests].payload.id=="Dunes","Portal menu must request locked world unlocks through the server")
				assert(not textExists("Choose a world"),"Successful world unlock must close the portal menu")
			else click("×") end
			portal:Destroy()
		end
		click("Gear");click("Boosts");assert(textExists("2x Growth / $500"),"Gear boost section must work");click("×")
		local fullCollection=state.brainrots
		state.brainrots={fullCollection[1]}
		state.garden.slots={"pet-1","","","","",""}
		click("Index");click("All rarities")
		assert(textExists("Brainrot index") and textExists("1 / "..#Config.Creatures.." discovered"),"Index book must show unique lifetime progress")
		local indexGrid=screen:FindFirstChild("IndexGrid",true)
		if size.X<440 then assert(indexGrid:GetAttribute("CardColumns")==1,"Index sculptures must stay comfortably sized on phones") end
		local unknown=0
		for _,object in uiNodes do if object.ClassName=="ViewportFrame" and visible(object) and object:GetAttribute("Silhouette") then unknown+=1 end end
		assert(unknown==#Config.Creatures-1 and textExists("???"),"Uncaught species must use hidden names and silhouette previews")
		local commonCount=0;for _,spec in Config.Creatures do if spec.rarity=="Common" then commonCount+=1 end end
		click("Common 1/"..commonCount)
		local entries=0
		for _,object in uiNodes do if visible(object) and object:GetAttribute("IndexSpecies") then entries+=1 end end
		assert(entries==commonCount,"Index rarity chapters must filter to that rarity's species")
		state.brainrots={}
		click("Index book")
		assert(textExists("1 / "..#Config.Creatures.." discovered"),"Selling all owned creatures must not erase the client index")
		state.brainrots={fullCollection[1]}
		click("My garden")
		assert(textExists("My garden") and textExists("Garden 01"),"Garden management must identify the assigned plot")
		local gardenHero=screen:FindFirstChild("GardenHero",true)
		if gardenHero:GetAttribute("Stacked") then
			local gardenStage=bounds(gardenHero:FindFirstChild("SculptureStage"),gardenHero.AbsoluteSize.X,gardenHero.AbsoluteSize.Y)
			local gardenTitle=bounds(gardenHero:FindFirstChild("GardenHeroTitle"),gardenHero.AbsoluteSize.X,gardenHero.AbsoluteSize.Y)
			local gardenIncome=bounds(gardenHero:FindFirstChild("GardenHeroIncome"),gardenHero.AbsoluteSize.X,gardenHero.AbsoluteSize.Y)
			assert(gardenTitle.top>=gardenStage.bottom+8 and gardenIncome.bottom<=gardenHero.AbsoluteSize.Y-62,"Stacked garden labels must stay clear of the sculpture and clear-slot touch target")
		end
		click("Slot 2");click("Move here")
		assert(requests[#requests].kind=="GardenAssign" and requests[#requests].payload.uid=="pet-1" and requests[#requests].payload.slot==2,"Garden controls must move the selected owned creature to its selected slot")
		assert(textExists("Clear slot"),"Assigned garden slots must offer clearing")
		click("Clear slot")
		assert(requests[#requests].kind=="GardenClear" and requests[#requests].payload.slot==2,"Clear controls must target the selected slot")
		click("Place here")
		click("Travel to my garden")
		assert(requests[#requests].kind=="Teleport" and requests[#requests].payload.destination=="Garden","Garden travel must request the caller's own garden")
		state.brainrots=fullCollection
		rendered.RenderStepped:Fire(0.3)
	end
	local function searches()
		local count=0
		for _,request in requests do if request.kind=="StartDig" then count+=1 end end
		return count
	end
	local beforeSearches=searches()
	click("Dig  ·  E")
	assert(gameScreen:GetAttribute("Scanning")==true and gameScreen:GetAttribute("Capturing")==false,"A pending scan must suspend sprint without claiming a capture")
	assert(textExists("Scanning…"),"The button must visibly stay busy while waiting for a result")
	click("Scanning…")
	assert(searches()==beforeSearches+1,"Clicking again during a scan must not send another request")
	advance(Config.SearchSeconds-0.01)
	assert(textExists("Scanning…") and not textExists("Tap to collect"),"No capture sheet may open before the scan result")
	advance(0.02)
	assert(gameScreen:GetAttribute("Scanning")==false and gameScreen:GetAttribute("Capturing")==false,"An empty scan must release the movement block")
	assert(textExists("Dig  ·  E") and not textExists("Tap to collect"),"An empty scan must reset the button without showing capture controls")
	assert(textExists("No signal this time. Try another spot in the sand."),"An empty scan needs clear feedback")
	click("Dig  ·  E")
	advance(Config.SearchSeconds+0.001)
	assert(textExists("Tap to collect"),"A successful delayed search must open the capture sheet")
	local timer=gameScreen:FindFirstChild("CaptureTimer",true)
	local meter=gameScreen:FindFirstChild("CaptureProgressTrack",true)
	assert(timer.Position.Y.Offset+timer.Size.Y.Offset+8<=meter.Position.Y.Offset,"The capture timer and progress meter must keep a comfortable visual gap")
	assert(gameScreen:GetAttribute("Capturing")==true and gameScreen:GetAttribute("Scanning")==false,"A capture must suspend sprint until finished")
	assert(controlsHidden(),"The capture challenge must hide the detector HUD")
	detector.Parent=backpack
	assert(controlsHidden() and textExists("Tap to collect"),"Unequipping must hide detector controls while allowing an accepted capture to finish")
	click("Tap to collect")
	assert(gameScreen:GetAttribute("Capturing")==false,"Finishing a capture must restore exploration input")
	assert(controlsHidden(),"Ending a capture while unequipped must not re-show the detector HUD")
	assert(not visible((function() for i=#uiNodes,1,-1 do if uiNodes[i].Text=="Tap to collect" then return uiNodes[i] end end end)()),"Completed capture must close")
	detector.Parent=player.Character
	assert(controlsShown(),"Re-equipping after a capture must restore detector controls")
	local oldCharacter=player.Character
	local oldHumanoid=oldCharacter:FindFirstChildOfClass("Humanoid")
	oldHumanoid.Health=0;oldHumanoid.Died:Fire()
	assert(controlsHidden(),"Death must hide detector controls immediately")
	player.CharacterRemoving:Fire(oldCharacter)
	player.Character=nil
	assert(controlsHidden(),"Removing a character must leave the detector HUD hidden")
	local replacement=Instance.new("Model")
	local newHumanoid=Instance.new("Humanoid");newHumanoid.Health=100;newHumanoid.Parent=replacement
	prepareCharacter(replacement)
	player.Character=replacement;player.CharacterAdded:Fire(replacement)
	assert(controlsHidden(),"Respawning without a held tool must not inherit the old detector HUD")
	detector.Parent=replacement
	assert(controlsShown(),"A detector equipped after respawn must work with the new character")
	oldHumanoid.Died:Fire()
	assert(controlsShown(),"An old character event must not hide the new character's detector HUD")
	detector:Destroy()
	assert(controlsHidden(),"Destroying an equipped detector must hide its controls")
	print("PASS client pages, centered left dock bounds, aligned navigation icons, modal clearance, equipped detector visibility, sprint input states, persistent index, gardens, portal travel and delayed searches")
end
