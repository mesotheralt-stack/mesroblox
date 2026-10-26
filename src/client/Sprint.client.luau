-- Shift holds sprint; controller L3 and the touch button toggle it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("BrainrotSprint")
local gui = player:WaitForChild("PlayerGui")
local hud = gui:WaitForChild("BrainrotBloom")
local desired = false
local lastSent = -math.huge
local humanoid = nil
local character = nil
local death = nil

local screen = Instance.new("ScreenGui")
screen.Name = "BrainrotSprint"
screen.ResetOnSpawn = false
screen.DisplayOrder = 11
screen.Parent = gui
local touch = Instance.new("TextButton")
touch.Name = "SprintToggle"
touch.AnchorPoint = Vector2.new(1, 1)
touch.Position = UDim2.new(1, -24, 1, -174)
touch.Size = UDim2.fromOffset(64, 64)
touch.BorderSizePixel = 0
touch.AutoButtonColor = false
touch.Font = Enum.Font.BuilderSansMedium
touch.TextSize = 13
touch.TextWrapped = true
touch.Parent = screen
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 22)
corner.Parent = touch
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(162, 184, 168)
stroke.Transparency = 0.45
stroke.Thickness = 1
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = touch

local function blocked()
	return UserInputService:GetFocusedTextBox() ~= nil
		or hud:GetAttribute("MenuOpen") == true or hud:GetAttribute("Capturing") == true or hud:GetAttribute("Scanning") == true
		or player.Character ~= character or not humanoid or humanoid.Health <= 0 or humanoid.Sit
end
local function paint()
	touch.Visible = UserInputService.TouchEnabled and not blocked()
	touch.Text = desired and "Sprint\nON" or "Sprint"
	touch.BackgroundColor3 = desired and Color3.fromRGB(66, 112, 89) or Color3.fromRGB(248, 247, 239)
	touch.TextColor3 = desired and Color3.fromRGB(250, 249, 241) or Color3.fromRGB(43, 67, 54)
end
local function setDesired(enabled)
	enabled = enabled and not blocked()
	if enabled ~= desired then
		desired = enabled
		lastSent = os.clock()
		remote:FireServer(enabled)
	end
	paint()
end
local function cancel() setDesired(false) end
local function bindCharacter(nextCharacter)
	cancel()
	if death then death:Disconnect(); death = nil end
	character, humanoid = nextCharacter, nil
	local nextHumanoid = nextCharacter:WaitForChild("Humanoid", 10)
	if player.Character ~= nextCharacter or character ~= nextCharacter then return end
	if nextHumanoid and nextHumanoid:IsA("Humanoid") then
		humanoid = nextHumanoid
		death = humanoid.Died:Connect(cancel)
	end
	paint()
end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function(leaving)
	if leaving ~= character then return end
	cancel()
	character, humanoid = nil, nil
	if death then death:Disconnect(); death = nil end
	paint()
end)
if player.Character then task.spawn(bindCharacter, player.Character) end

ContextActionService:BindAction("BrainrotSprintHold", function(_, inputState)
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then cancel()
	elseif inputState == Enum.UserInputState.Begin then setDesired(true) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
ContextActionService:BindAction("BrainrotSprintToggle", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then setDesired(not desired) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonL3)
touch.Activated:Connect(function() setDesired(not desired) end)
UserInputService.TextBoxFocused:Connect(cancel)
UserInputService.WindowFocusReleased:Connect(cancel)
for _, attribute in {"MenuOpen", "Capturing", "Scanning"} do
	hud:GetAttributeChangedSignal(attribute):Connect(function()
		if blocked() then cancel() else paint() end
	end)
end
RunService.Heartbeat:Connect(function()
	if desired and blocked() then cancel() end
	-- Recover a held input rejected by the short server start limit. Only retry
	-- while waiting for acknowledgement; successful sprint sends no frame traffic.
	if desired and character:GetAttribute("Sprinting") ~= true and os.clock() - lastSent >= 0.25 then
		lastSent = os.clock()
		remote:FireServer(true)
	end
	paint()
end)
paint()
