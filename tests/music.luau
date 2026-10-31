-- Execute the actual music LocalScript against clock/audio-service doubles.
-- These verify scheduling and lifecycle, not sample decoding or audible quality.
local musicClock = 0
local os = {clock=function() return musicClock end}
local signals = {}
local function signal()
	local event = {listeners={}}
	function event:Connect(fn)
		local item = {Connected=true,fn=fn}
		function item:Disconnect() self.Connected=false end
		table.insert(self.listeners,item)
		return item
	end
	function event:Fire(...)
		for _,item in table.clone(self.listeners) do if item.Connected then item.fn(...) end end
	end
	function event:Count()
		local count=0;for _,item in self.listeners do if item.Connected then count+=1 end end
		return count
	end
	table.insert(signals,event)
	return event
end
local nodes,plays = {},{}
local function node(class)
	local item={ClassName=class,Name=class,_children={},_attrs={},_signals={},Destroying=signal(),Playing=false}
	function item:FindFirstChild(name)
		for _,child in self._children do if child.Name==name and not child.Destroyed then return child end end
	end
	function item:WaitForChild(name) local result=assert(self:FindFirstChild(name),"Missing audio fixture child "..name);return result end
	function item:GetAttribute(key) return self._attrs[key] end
	function item:GetAttributeChangedSignal(key) self._signals[key]=self._signals[key] or signal();return self._signals[key] end
	function item:SetAttribute(key,value)
		local previous=self._attrs[key];self._attrs[key]=value
		if previous~=value and self._signals[key] then self._signals[key]:Fire() end
	end
	function item:Stop() self.Playing=false end
	function item:Play()
		assert(not self.Destroyed,"Destroyed music voices cannot restart")
		self.Playing=true
		table.insert(plays,{sound=self,time=musicClock,group=self.SoundGroup,speed=self.PlaybackSpeed,volume=self.Volume})
	end
	function item:Destroy()
		if self.Destroyed then return end
		self.Destroying:Fire();self.Destroyed=true;self.Playing=false
		for _,child in table.clone(self._children) do child:Destroy() end
	end
	table.insert(nodes,item)
	return setmetatable(item,{__newindex=function(self,key,value)
		if key=="Parent" then
			rawset(self,key,value)
			if value then table.insert(value._children,self) end
		else rawset(self,key,value) end
	end})
end
local Instance={new=node}
local musicScreen=node("ScreenGui");musicScreen.Name="BrainrotBloom"
local musicGui=node("PlayerGui");musicGui.Name="PlayerGui";musicScreen.Parent=musicGui
local musicPlayer=node("Player");musicGui.Parent=musicPlayer
local musicSounds=node("SoundService")
local musicRun={Heartbeat=signal()}
local script=node("LocalScript")
local game={GetService=function(_,name)
	return assert(({Players={LocalPlayer=musicPlayer},SoundService=musicSounds,RunService=musicRun})[name],name)
end}

local function verifyMusic()
	local checks=0
	local function check(value,message) checks+=1;assert(value,message) end
	local function frame(dt) musicClock+=dt;musicRun.Heartbeat:Fire(dt) end
	local function advance(duration)
		for _=1,math.ceil(duration/0.05) do frame(0.05) end
	end
	local bank=musicSounds:WaitForChild("BrainrotMusic")
	check(bank.ClassName=="SoundGroup" and bank.Volume==1,"Music must have a dedicated legal SoundService mixing group")
	local groups,voices={},{}
	for _,item in nodes do
		if item.ClassName=="Sound" then
			table.insert(voices,item)
			check(item.SoundId=="rbxasset://sounds/electronicpingshort.wav" and not item.Looped,"Original music must use the bundled note sample without upload permissions or infinite sample loops")
			check(item.SoundGroup and item.SoundGroup.Parent==bank,"Every music voice must route through the separate music mixer")
		elseif item.ClassName=="SoundGroup" and item~=bank then table.insert(groups,item) end
	end
	check(#voices==16 and #groups==2,"Music must bound its polyphony and crossfade channels")
	local initialInstances=#nodes
	check(bank:GetAttribute("Theme")=="Clover Afternoon","Missing world metadata must start the gentle starter-world theme")
	frame(0.1)
	check(#plays==0,"Music should fade in before playing its first notes")
	advance(1)
	check(#plays>0,"The default score must actually schedule notes")
	local firstGroup=plays[1].group
	advance(3)
	check(firstGroup.Volume>0.9 and firstGroup.Volume<=1,"Exploration music must fade to its bounded listening level")
	local beforeSame=#plays
	musicScreen:SetAttribute("MusicWorld","Meadow")
	check(bank:GetAttribute("Theme")=="Clover Afternoon" and firstGroup.Volume>0.9,"Repeated world state must not restart or fade out the current score")
	check(#plays==beforeSame,"World state updates must not inject extra notes")
	musicScreen:SetAttribute("Scanning",true);advance(3)
	check(firstGroup.Volume>0.44 and firstGroup.Volume<0.46,"A scan must lower music so detector feedback remains audible")
	musicScreen:SetAttribute("Capturing",true);advance(3)
	check(firstGroup.Volume>0.27 and firstGroup.Volume<0.29,"Captures must duck music further, including when the scan attribute is still set")
	musicScreen:SetAttribute("Scanning",false);musicScreen:SetAttribute("Capturing",false);advance(3)
	check(firstGroup.Volume>0.99,"Exploration volume must return after capture")
	musicScreen:SetAttribute("SoundMuted",true)
	local beforeEffectsMute=#plays;advance(2)
	check(#plays>beforeEffectsMute and firstGroup.Volume>0.99,"Muting sound effects must leave music playing")
	musicScreen:SetAttribute("MusicMuted",true)
	for _,group in groups do check(group.Volume==0,"Music mute must silence both crossfade channels immediately") end
	for _,voice in voices do check(not voice.Playing,"Music mute must stop all ringing voices") end
	local beforeMuted=#plays;advance(15)
	check(#plays==beforeMuted,"Muted music must schedule no audible notes")
	musicScreen:SetAttribute("MusicMuted",false)
	frame(0.05)
	check(#plays-beforeMuted<=3,"Unmuting must not replay the backlog of muted beats")
	advance(3)
	check(#plays>beforeMuted and firstGroup.Volume>0.9,"Unmuting must resume the ongoing score with a gentle fade")

	local themePitches={Meadow=plays[1].speed}
	for _,entry in {{"Dunes","Sandstone Reverie",66},{"Cosmic","Moonbloom Drift",60},{"Meadow","Clover Afternoon",72}} do
		local outgoing=plays[#plays].group
		local prior=outgoing.Volume
		local before=#plays
		musicScreen:SetAttribute("MusicWorld",entry[1])
		check(bank:GetAttribute("Theme")==entry[2],"Each world must select its own original score")
		check(outgoing.Volume==prior,"Portal transitions must retain the old note tail for a crossfade")
		frame(0.1)
		check(outgoing.Volume<prior and outgoing.Volume>0,"The outgoing music must fade rather than cut abruptly")
		advance(0.3)
		check(#plays>before,"A world theme must start without waiting for a previous track to finish")
		local incoming=plays[before+1].group
		check(incoming~=outgoing and incoming.Volume>0 and incoming.Volume<1,"World themes must crossfade through independent channels")
		themePitches[entry[1]]=plays[before+1].speed
		advance(4)
		check(outgoing.Volume<0.001 and incoming.Volume>0.99,"A completed crossfade must silence the old theme")
		for i=before+1,#plays do check(plays[i].group==incoming,"Only the newly selected score may emit notes after travel") end
		local shortest,lastTime=math.huge,nil
		for i=before+1,#plays do
			if lastTime and plays[i].time>lastTime+0.001 then shortest=math.min(shortest,plays[i].time-lastTime) end
			lastTime=plays[i].time
		end
		check(math.abs(shortest-60/entry[3]/2)<0.055,"Each theme must keep its intended relaxed tempo on the frame clock")
	end
	check(themePitches.Meadow~=themePitches.Dunes and themePitches.Meadow~=themePitches.Cosmic and themePitches.Dunes~=themePitches.Cosmic,"World themes must sound musically different, not only change a label")
	musicScreen:SetAttribute("MusicWorld","unknown")
	check(bank:GetAttribute("Theme")=="Clover Afternoon","Unknown world state must fall back safely")
	local beforeStall=#plays
	frame(180)
	check(#plays-beforeStall<=3,"A long stalled frame must skip missed beats without an audio burst")
	advance(120)
	check(#nodes==initialInstances,"Long sessions must reuse a fixed voice bank instead of allocating sounds per note")
	for _,play in plays do
		check(play.speed==play.speed and play.speed>0 and play.speed<=2,"Every scheduled pitch must remain finite and valid")
		check(play.volume>0 and play.volume<=0.1,"Background notes must stay quiet enough for gameplay feedback")
	end
	musicScreen:Destroy()
	check(bank.Destroyed and musicRun.Heartbeat:Count()==0,"Removing the interface must destroy the music bank and disconnect its frame loop")
	local beforeCleanup=#plays
	frame(1);script:Destroy()
	check(#plays==beforeCleanup,"Destroying either client owner must prevent future playback")
	for _,event in signals do check(event:Count()==0,"Music cleanup must disconnect every owned listener") end
	print("PASS actual original music client ("..checks.." checks: world scores, note scheduling, independent mute, ducking, crossfades, bounded voices, stalls and cleanup)")
end
