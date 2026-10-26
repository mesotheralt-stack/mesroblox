-- The runner inserts the actual sprint scripts between these fixture/checks.
-- These doubles verify input/state transitions, not Roblox physics or routing.
local sprintClock = 1
local os = {clock=function() return sprintClock end}
local task = {spawn=function(fn, ...) fn(...) end}
local function sprintSignal()
	local listeners = {}
	return {
		Connect=function(_, fn)
			local connection = {Connected=true}
			function connection:Disconnect() self.Connected=false end
			table.insert(listeners, {fn=fn, connection=connection})
			return connection
		end,
		Fire=function(_, ...)
			for _, entry in table.clone(listeners) do if entry.connection.Connected then entry.fn(...) end end
		end,
	}
end
local function sprintNode(class)
	local node = {ClassName=class, Name=class, _children={}, _attrs={}, _attrSignals={}}
	function node:IsA(wanted) return wanted==self.ClassName end
	function node:FindFirstChild(name) for _, child in self._children do if child.Name==name then return child end end; return nil end
	function node:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing sprint fixture child "..name) end
	function node:GetAttribute(key) return self._attrs[key] end
	function node:GetAttributeChangedSignal(key) self._attrSignals[key]=self._attrSignals[key] or sprintSignal(); return self._attrSignals[key] end
	function node:SetAttribute(key, value)
		local previous=self._attrs[key]; self._attrs[key]=value
		if previous~=value and self._attrSignals[key] then self._attrSignals[key]:Fire() end
	end
	if class=="RemoteEvent" then node.OnServerEvent=sprintSignal() end
	if class=="TextButton" then node.Activated=sprintSignal() end
	return setmetatable(node, {__newindex=function(self, key, value)
		if key=="Parent" then rawset(self,key,value); if value then table.insert(value._children,self) end
		else rawset(self,key,value) end
	end})
end
local Instance = {new=sprintNode}
local Enum = setmetatable({}, {__index=function(_, group)
	return setmetatable({}, {__index=function(_, name) return group.."."..name end})
end})
local UDim2 = {new=function(...) return {...} end, fromOffset=function(...) return {...} end}
local UDim = {new=function(...) return {...} end}
local Vector2 = {new=function(...) return {...} end}
local Color3 = {fromRGB=function(...) return {...} end}
local sprintPlayers = sprintNode("Players")
sprintPlayers.PlayerAdded, sprintPlayers.PlayerRemoving = sprintSignal(), sprintSignal()
local sprintReplicated = sprintNode("ReplicatedStorage")
local focused = nil
local sprintInput = {TouchEnabled=true, TextBoxFocused=sprintSignal(), WindowFocusReleased=sprintSignal(), GetFocusedTextBox=function() return focused end}
local sprintBindings = {}
local sprintActions = {BindAction=function(_, name, callback) sprintBindings[name]=callback end}
local sprintRun = {Heartbeat=sprintSignal()}
local game = {GetService=function(_, name)
	return assert(({Players=sprintPlayers, ReplicatedStorage=sprintReplicated, UserInputService=sprintInput, ContextActionService=sprintActions, RunService=sprintRun})[name], name)
end}
local function sprintCharacter()
	local character = sprintNode("Model")
	local humanoid = sprintNode("Humanoid")
	humanoid.Name="Humanoid"; humanoid.Health=100; humanoid.WalkSpeed=0; humanoid.Sit=false; humanoid.Died=sprintSignal(); humanoid.Parent=character
	return character, humanoid
end
local function sprintPlayer()
	local player = sprintNode("Player")
	player.Parent=sprintPlayers
	player.CharacterAdded, player.CharacterRemoving = sprintSignal(), sprintSignal()
	player.Character=sprintCharacter()
	return player
end
local sprintOwner = sprintPlayer()
function sprintPlayers:GetPlayers() return {sprintOwner} end
local sprintRemote
local sprintChecks = 0
local function expect(value, message) sprintChecks+=1; assert(value, message) end

local function verifySprintServer()
	sprintRemote = sprintReplicated:WaitForChild("BrainrotSprint")
	local function request(value) sprintRemote.OnServerEvent:Fire(sprintOwner, value) end
	local character=sprintOwner.Character
	local humanoid=character:WaitForChild("Humanoid")
	expect(humanoid.WalkSpeed==16 and character:GetAttribute("Sprinting")==false, "Existing character starts at walking speed")
	for _, bad in {"true", 26, {}, {speed=100}} do request(bad) end
	expect(humanoid.WalkSpeed==16, "Non-boolean speed/toggle payloads are ignored")
	request(true)
	expect(humanoid.WalkSpeed==26 and character:GetAttribute("Sprinting"), "Sprint starts at fixed server speed")
	request(false)
	expect(humanoid.WalkSpeed==16, "Immediate releases are never rate limited")
	request(true)
	expect(humanoid.WalkSpeed==16, "Rapid restart is limited")
	sprintClock+=0.2; request(true)
	expect(humanoid.WalkSpeed==26, "Sprint can restart after cooldown")
	humanoid.Health=0; humanoid.Died:Fire()
	expect(humanoid.WalkSpeed==16 and not character:GetAttribute("Sprinting"), "Death resets speed and state")
	sprintClock+=0.2; request(true)
	expect(humanoid.WalkSpeed==16, "Dead character cannot sprint")
	sprintOwner.CharacterRemoving:Fire(character)
	local nextCharacter, nextHumanoid=sprintCharacter()
	sprintOwner.Character=nextCharacter; sprintOwner.CharacterAdded:Fire(nextCharacter)
	expect(nextHumanoid.WalkSpeed==16 and not nextCharacter:GetAttribute("Sprinting"), "Respawn clears prior sprint")
	request(true); humanoid.Died:Fire()
	expect(nextHumanoid.WalkSpeed==26, "Old death signal cannot cancel the new character")
	request(false); nextHumanoid.Sit=true; sprintClock+=0.2; request(true)
	expect(nextHumanoid.WalkSpeed==16, "Seated characters cannot start sprint")
	nextHumanoid.Sit=false
	local stranger=sprintPlayer()
	sprintRemote.OnServerEvent:Fire(stranger,true)
	expect(stranger.Character:WaitForChild("Humanoid").WalkSpeed==0, "Unregistered player cannot request sprint")
	sprintPlayers.PlayerAdded:Fire(stranger)
	sprintRemote.OnServerEvent:Fire(stranger,true)
	expect(stranger.Character:WaitForChild("Humanoid").WalkSpeed==26, "New players are wired independently")
	sprintPlayers.PlayerRemoving:Fire(stranger)
	sprintRemote.OnServerEvent:Fire(stranger,true)
	expect(stranger.Character:WaitForChild("Humanoid").WalkSpeed==16, "Departure clears sprint and denies late requests")
	-- Prepare a local client sharing the authoritative remote.
	sprintPlayers.LocalPlayer=sprintOwner
	local gui=sprintNode("PlayerGui"); gui.Parent=sprintOwner
	local hud=sprintNode("ScreenGui"); hud.Name="BrainrotBloom"; hud.Parent=gui
	function sprintRemote:FireServer(value) self.OnServerEvent:Fire(sprintOwner,value) end
	sprintClock+=0.2
end

local function verifySprintClient()
	local gui=sprintOwner:WaitForChild("PlayerGui")
	local hud=gui:WaitForChild("BrainrotBloom")
	local toggle=gui:WaitForChild("BrainrotSprint"):WaitForChild("SprintToggle")
	local humanoid=sprintOwner.Character:WaitForChild("Humanoid")
	local function hold(state) sprintBindings.BrainrotSprintHold(nil, Enum.UserInputState[state]) end
	local function controller() sprintBindings.BrainrotSprintToggle(nil, Enum.UserInputState.Begin) end
	expect(toggle.Visible and toggle.Text=="Sprint", "Touch control starts visible and idle")
	hold("Begin")
	expect(humanoid.WalkSpeed==26, "Shift starts sprint through real remote handler")
	hold("End")
	expect(humanoid.WalkSpeed==16, "Shift release walks")
	hold("Begin")
	expect(humanoid.WalkSpeed==16, "Rapid input may wait for server start limit")
	sprintClock+=0.3; sprintRun.Heartbeat:Fire()
	expect(humanoid.WalkSpeed==26, "Held input recovers from a rate-limited start")
	hold("End")
	sprintClock+=0.2; controller()
	expect(humanoid.WalkSpeed==26, "Controller L3 toggles sprint on")
	controller()
	expect(humanoid.WalkSpeed==16, "Controller L3 toggles sprint off")
	sprintClock+=0.2; toggle.Activated:Fire()
	expect(humanoid.WalkSpeed==26 and toggle.Text=="Sprint\nON", "Touch control toggles sprint")
	for _, attribute in {"MenuOpen", "Capturing", "Scanning"} do
		hud:SetAttribute(attribute,true)
		expect(humanoid.WalkSpeed==16 and not toggle.Visible, attribute.." immediately stops/hides sprint")
		sprintClock+=0.2; hold("Begin")
		expect(humanoid.WalkSpeed==16, attribute.." blocks Shift")
		hud:SetAttribute(attribute,false)
		expect(toggle.Visible and humanoid.WalkSpeed==16, "Closing UI does not auto-resume sprint")
	end
	sprintClock+=0.2; hold("Begin"); focused={}; sprintInput.TextBoxFocused:Fire()
	expect(humanoid.WalkSpeed==16, "Typing cancels sprint")
	hold("Begin"); expect(humanoid.WalkSpeed==16, "Typing cannot trigger sprint")
	focused=nil; sprintClock+=0.2; hold("Begin"); sprintInput.WindowFocusReleased:Fire()
	expect(humanoid.WalkSpeed==16, "Window focus loss cancels sprint")
	sprintClock+=0.2; hold("Begin"); humanoid.Sit=true; sprintRun.Heartbeat:Fire()
	expect(humanoid.WalkSpeed==16 and not toggle.Visible, "Sitting clears local sprint")
	humanoid.Sit=false; sprintRun.Heartbeat:Fire()
	sprintClock+=0.2; hold("Begin"); humanoid.Health=0; humanoid.Died:Fire()
	expect(humanoid.WalkSpeed==16 and not toggle.Visible, "Death clears local sprint")
	local oldCharacter=sprintOwner.Character
	sprintOwner.CharacterRemoving:Fire(oldCharacter)
	local nextCharacter, nextHumanoid=sprintCharacter()
	sprintOwner.Character=nextCharacter; sprintOwner.CharacterAdded:Fire(nextCharacter)
	expect(toggle.Visible and nextHumanoid.WalkSpeed==16, "Touch control recovers after respawn")
	sprintClock+=0.2; hold("Begin")
	expect(nextHumanoid.WalkSpeed==26, "Sprint works on the respawned character")
	hold("Cancel")
	expect(nextHumanoid.WalkSpeed==16, "Canceled input releases sprint")
	print("PASS actual sprint server/client ("..sprintChecks.." checks: fixed speeds, input methods, modal cancellation, respawn, validation and cleanup)")
end
