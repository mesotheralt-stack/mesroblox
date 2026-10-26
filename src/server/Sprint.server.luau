-- Fixed movement speeds are chosen by the server, never supplied by clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WALK_SPEED = 16
local SPRINT_SPEED = 26
local START_INTERVAL = 0.12
local states = {}
local remote = Instance.new("RemoteEvent")
remote.Name = "BrainrotSprint"
remote.Parent = ReplicatedStorage

local function stop(state)
	if state.humanoid then state.humanoid.WalkSpeed = WALK_SPEED end
	if state.character then state.character:SetAttribute("Sprinting", false) end
end

local function watchPlayer(player)
	if states[player] then return end
	local state = {lastStart = -math.huge}
	states[player] = state
	local function characterAdded(character)
		stop(state)
		if state.death then state.death:Disconnect(); state.death = nil end
		state.character, state.humanoid = character, nil
		state.lastStart = -math.huge
		character:SetAttribute("Sprinting", false)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") or states[player] ~= state or player.Character ~= character or state.character ~= character then return end
		state.humanoid = humanoid
		humanoid.WalkSpeed = WALK_SPEED
		state.death = humanoid.Died:Connect(function() stop(state) end)
	end
	player.CharacterAdded:Connect(characterAdded)
	player.CharacterRemoving:Connect(function(character)
		if state.character ~= character then return end
		stop(state)
		if state.death then state.death:Disconnect(); state.death = nil end
		state.character, state.humanoid = nil, nil
	end)
	if player.Character then task.spawn(characterAdded, player.Character) end
end

remote.OnServerEvent:Connect(function(player, enabled)
	if type(enabled) ~= "boolean" then return end
	local state = states[player]
	if not state or player.Parent ~= Players then return end
	-- Releases are always accepted, even directly after a start or during spam.
	if not enabled then stop(state); return end
	local character, humanoid = state.character, state.humanoid
	if player.Character ~= character or not character or not humanoid or humanoid.Health <= 0 or humanoid.Sit then return end
	local now = os.clock()
	if now - state.lastStart < START_INTERVAL then return end
	state.lastStart = now
	humanoid.WalkSpeed = SPRINT_SPEED
	character:SetAttribute("Sprinting", true)
end)

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	local state = states[player]
	if not state then return end
	stop(state)
	if state.death then state.death:Disconnect() end
	states[player] = nil
end)
for _, player in Players:GetPlayers() do watchPlayer(player) end
