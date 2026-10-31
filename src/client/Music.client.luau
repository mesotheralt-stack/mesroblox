-- Original eight-bar ambient scores played from one Roblox-bundled bell sample.
-- Everything is local: no uploaded audio, remotes, or gameplay timers are used.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local screen = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BrainrotBloom")

-- Semitone intervals share the same sample, so bass, arpeggios and melodies
-- remain in tune without depending on a third-party recording's concert pitch.
local scores = {
	Meadow = {
		name = "Clover Afternoon", bpm = 72, transpose = 0,
		chords = {{0,4,7}, {9,12,16}, {5,9,12}, {7,11,14}},
		melody = {
			{7,false,9,7,4,false,2,false}, {4,false,7,false,9,7,4,false},
			{5,false,9,12,9,false,7,false}, {7,false,4,false,2,false,false,false},
			{4,false,7,9,7,false,4,false}, {9,false,12,false,7,false,4,false},
			{9,false,7,5,4,false,2,false}, {2,false,4,false,0,false,false,false},
		},
	},
	Dunes = {
		name = "Sandstone Reverie", bpm = 66, transpose = -2,
		chords = {{0,3,7}, {8,12,15}, {5,8,12}, {7,10,14}},
		melody = {
			{7,false,false,3,5,false,7,false}, {8,false,7,false,3,false,false,false},
			{5,false,false,8,7,false,5,false}, {2,false,3,false,2,false,false,false},
			{3,false,7,false,10,false,7,false}, {8,false,false,7,3,false,false,false},
			{5,false,8,false,7,5,3,false}, {2,false,false,3,0,false,false,false},
		},
	},
	Cosmic = {
		name = "Moonbloom Drift", bpm = 60, transpose = 2,
		chords = {{0,4,7}, {2,6,9}, {9,12,16}, {7,11,14}},
		melody = {
			{12,false,false,7,6,false,4,false}, {9,false,6,false,2,false,false,false},
			{9,false,false,12,7,false,4,false}, {11,false,9,false,7,false,false,false},
			{7,false,12,false,6,false,4,false}, {6,false,false,9,6,false,2,false},
			{4,false,7,false,12,false,9,false}, {7,false,false,4,0,false,false,false},
		},
	},
}

local bank = Instance.new("SoundGroup")
bank.Name = "BrainrotMusic"
bank.Volume = 1
bank.Parent = SoundService
local connections = {}
local channels = {}
for index = 1, 2 do
	local group = Instance.new("SoundGroup")
	group.Name = "Theme" .. index
	group.Volume = 0
	group.Parent = bank
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -3; eq.MidGain = -5; eq.HighGain = -15
	eq.Parent = group
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.4; reverb.Density = 0.5; reverb.Diffusion = 0.7
	reverb.DryLevel = -2; reverb.WetLevel = -18
	reverb.Parent = group
	local channel = {group = group, voices = {}, cursor = 0, gain = 0, stopped = true}
	for voice = 1, 8 do
		local sound = Instance.new("Sound")
		sound.Name = "Note" .. voice
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.SoundGroup = group
		sound.Volume = 0
		sound.Looped = false
		sound.Parent = bank
		table.insert(channel.voices, sound)
	end
	table.insert(channels, channel)
end

local activeIndex = 0
local currentWorld
local score
local step = 0
local nextNote = 0
local alive = true
local function stopChannel(channel)
	if channel.stopped then return end
	for _, sound in channel.voices do sound:Stop() end
	channel.stopped = true
end
local function selectWorld()
	local requested = screen:GetAttribute("MusicWorld")
	local world = scores[requested] and requested or "Meadow"
	if world == currentWorld then return end
	currentWorld = world
	score = scores[world]
	activeIndex = activeIndex % 2 + 1
	local channel = channels[activeIndex]
	stopChannel(channel)
	channel.gain = 0
	channel.group.Volume = 0
	step = 0
	nextNote = os.clock() + 0.35
	bank:SetAttribute("Theme", score.name)
end
local function syncMute()
	if screen:GetAttribute("MusicMuted") == true then
		for _, channel in channels do
			stopChannel(channel)
			channel.gain = 0
			channel.group.Volume = 0
		end
	end
end
local function note(channel, semitone, volume)
	channel.stopped = false
	channel.cursor = channel.cursor % #channel.voices + 1
	local sound = channel.voices[channel.cursor]
	sound:Stop()
	sound.PlaybackSpeed = 2 ^ ((semitone + score.transpose) / 12)
	sound.Volume = volume
	sound:Play()
end

table.insert(connections, screen:GetAttributeChangedSignal("MusicWorld"):Connect(selectWorld))
table.insert(connections, screen:GetAttributeChangedSignal("MusicMuted"):Connect(syncMute))
selectWorld()
syncMute()
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	local muted = screen:GetAttribute("MusicMuted") == true
	local duck = screen:GetAttribute("Capturing") and 0.28 or screen:GetAttribute("Scanning") and 0.45 or 1
	local blend = 1 - math.exp(-math.min(dt, 0.1) * 3)
	for index, channel in channels do
		local target = not muted and index == activeIndex and duck or 0
		channel.gain += (target - channel.gain) * blend
		channel.group.Volume = channel.gain
		if index ~= activeIndex and channel.gain < 0.001 then stopChannel(channel) end
	end
	local now = os.clock()
	if now < nextNote then return end
	local interval = 60 / score.bpm / 2
	-- Advance the score across stalls and muted periods without playing a burst
	-- of missed notes when a window regains focus or the player unmutes music.
	local skipped = math.floor((now - nextNote) / interval)
	step = (step + skipped) % 64
	nextNote += (skipped + 1) * interval
	if not muted then
		local channel = channels[activeIndex]
		local bar = math.floor(step / 8)
		local beat = step % 8
		local chord = score.chords[bar % #score.chords + 1]
		if beat == 0 then note(channel, chord[1] - 36, 0.045) end
		if beat % 2 == 0 then
			local tone = ({1, 3, 2, 3})[beat / 2 + 1]
			note(channel, chord[tone] - 24, 0.055)
		end
		local melody = score.melody[bar + 1][beat + 1]
		if melody then note(channel, melody - 12, 0.075) end
	end
	step = (step + 1) % 64
end))

local function cleanup()
	if not alive then return end
	alive = false
	for _, connection in connections do connection:Disconnect() end
	for _, channel in channels do stopChannel(channel) end
	bank:Destroy()
end
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, screen.Destroying:Connect(cleanup))
