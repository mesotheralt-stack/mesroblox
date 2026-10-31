-- Local feedback uses Roblox's bundled audio, with no uploaded asset permissions.
local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local screen=Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BrainrotBloom")
local bank=Instance.new("Folder")
bank.Name="BrainrotFeedback";bank.Parent=SoundService
local definitions={
 Click={"switch.wav",0.08,1.3}, Scan={"electronicpingshort.wav",0.13,0.65},
 Found={"electronicpingshort.wav",0.22,1.25}, Miss={"switch.wav",0.1,0.7},
 Tap={"switch.wav",0.09,1.7}, Capture={"electronicpingshort.wav",0.3,1.6},
 Purchase={"electronicpingshort.wav",0.18,1.15}, Sell={"electronicpingshort.wav",0.2,0.95},
 Feed={"switch.wav",0.16,1.1}, Portal={"electronicpingshort.wav",0.22,0.8},
 Error={"switch.wav",0.12,0.6},
}
local sounds,last={},{}
for name,definition in definitions do
 local sound=Instance.new("Sound")
 sound.Name=name;sound.SoundId="rbxasset://sounds/"..definition[1]
 sound.Volume=definition[2];sound.PlaybackSpeed=definition[3];sound.Looped=false
 sound.Parent=bank;sounds[name]=sound
end
local function mute()
 if screen:GetAttribute("SoundMuted") then for _,sound in sounds do sound:Stop() end end
end
screen:GetAttributeChangedSignal("SoundMuted"):Connect(mute)
screen:GetAttributeChangedSignal("SoundCue"):Connect(function()
 if screen:GetAttribute("SoundMuted") then return end
 local cue=screen:GetAttribute("SoundCue")
 local name=type(cue)=="string" and string.match(cue,":(%a+)$")
 local sound=name and sounds[name]
 if not sound then return end
 local now=os.clock()
 if now-(last[name] or -math.huge)<0.075 then return end
 last[name]=now;sound:Stop();sound:Play()
end)
script.Destroying:Connect(function() bank:Destroy() end)
