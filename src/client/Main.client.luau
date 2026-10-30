-- Client presentation only. Inventory, purchases, digging, and rewards are server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("BrainrotShared")
local Config = require(shared:WaitForChild("Config"))
local CreatureFactory = require(shared:WaitForChild("CreatureFactory"))
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local Action = remotes:WaitForChild("Action")
local State = remotes:WaitForChild("State")
local Notify = remotes:WaitForChild("Notify")

-- Soft paper, deep evergreen and restrained brass keep the scenery in focus.
local C = {
	bg = Color3.fromRGB(25, 43, 39), panel = Color3.fromRGB(246, 247, 240),
	card = Color3.fromRGB(255, 255, 250), light = Color3.fromRGB(232, 238, 227),
	text = Color3.fromRGB(34, 52, 45), muted = Color3.fromRGB(94, 112, 102),
	lime = Color3.fromRGB(195, 221, 175), green = Color3.fromRGB(65, 111, 85),
	gold = Color3.fromRGB(139, 98, 42), red = Color3.fromRGB(168, 75, 65),
	paper = Color3.fromRGB(255, 254, 246), honey = Color3.fromRGB(238, 206, 141),
	line = Color3.fromRGB(210, 221, 207), alert = Color3.fromRGB(243, 161, 153),
}

local state = nil
local activePage = nil
local selectedUid = nil
local gearTab = "Detectors"
local chosenQuantity = 1
local collectionSort = "Income"
local collectionFilter = "All"
local collectionQuery = ""
local collectionPageIndex = 1
local collectionPageSize = 12
local indexRarityFilter = "All"
local indexVariant = "Normal"
local selectedGardenSlot = 1
local selectedGardenUid = nil
local panelRestPosition = UDim2.fromScale(0.5, 0.49)
local busy = false
local capture = nil
local capturePending = false
local viewports = {}
local renderPage
local resize
local renderedSignature = nil
local request
local openPage
local startDig
local tapDig

local screen = Instance.new("ScreenGui")
screen.Name = "BrainrotBloom"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 10
screen.Parent = player:WaitForChild("PlayerGui")
screen:SetAttribute("MenuOpen", false)
screen:SetAttribute("Capturing", false)
screen:SetAttribute("Scanning", false)

local function make(class, props, parent)
	local obj = Instance.new(class)
	for key, value in pairs(props or {}) do obj[key] = value end
	obj.Parent = parent
	return obj
end
local function corner(obj, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, obj)
end
local function stroke(obj, color, transparency)
	return make("UIStroke", {Color = color or C.line, Transparency = transparency or 0, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, obj)
end
local function label(parent, text, size, color, props)
	local p = {
		BackgroundTransparency = 1, Text = text, TextColor3 = color or C.text,
		Font = Enum.Font.BuilderSans, TextSize = math.max(13, size or 16),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in pairs(props or {}) do p[key] = value end
	return make("TextLabel", p, parent)
end
local function button(parent, text, onClick, props)
	local p = {
		Text = text, Font = Enum.Font.BuilderSansMedium, TextSize = 14,
		TextColor3 = C.text, BackgroundColor3 = C.light, BorderSizePixel = 0,
		Size = UDim2.new(0, 140, 0, 44), AutoButtonColor = false,
	}
	for key, value in pairs(props or {}) do p[key] = value end
	if p.Size.Y.Scale==0 and p.Size.Y.Offset<44 then p.Size=UDim2.new(p.Size.X.Scale,p.Size.X.Offset,0,44) end
	local b = make("TextButton", p, parent)
	corner(b, 12)
	local border=stroke(b,C.green,0.9)
	border.Name="InteractionBorder"
	local hovering=false
	local function outline(alpha)
		TweenService:Create(border,TweenInfo.new(0.12),{Transparency=alpha}):Play()
	end
	b.MouseEnter:Connect(function() hovering=true;outline(0.52) end)
	b.MouseLeave:Connect(function() hovering=false;outline(0.9) end)
	b.MouseButton1Down:Connect(function() outline(0.15) end)
	b.MouseButton1Up:Connect(function() outline(hovering and 0.52 or 0.9) end)
	if onClick then b.Activated:Connect(onClick) end
	return b
end
local function padding(parent, amount)
	make("UIPadding", {PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount),
		PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount)}, parent)
end
local function vertical(parent, gap)
	return make("UIListLayout", {Padding = UDim.new(0, gap or 10), SortOrder = Enum.SortOrder.LayoutOrder}, parent)
end
local function row(parent, height)
	return make("Frame", {Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1}, parent)
end
local function card(parent, height)
	local frame = make("Frame", {Name="ContentCard",Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.card, BorderSizePixel = 0}, parent)
	corner(frame, 14)
	local border=stroke(frame,C.line,0.35)
	border.Name="CardBorder"
	return frame
end
local function cardColumns()
	-- Comfortable name/stat widths matter more than squeezing tiny cards onto
	-- portrait phones. Larger viewports still show two or three at a time.
	return math.clamp(math.floor((screen.AbsoluteSize.X*0.94-28)/190),1,3)
end
local function readable(tint)
	return tint:Lerp(C.text,0.64)
end
local function badge(parent, text, tint, position, size)
	local field=label(parent,text,13,readable(tint),{Position=position,Size=size,
		BackgroundColor3=tint:Lerp(C.paper,0.82),TextXAlignment=Enum.TextXAlignment.Center,
		Font=Enum.Font.BuilderSansMedium})
	corner(field,8)
	return field
end
local function icon(parent, kind, tint, position, size)
	local root=make("Frame",{Position=position,Size=size,BackgroundTransparency=1},parent)
	local function mark(x,y,w,h,round,rotation)
		local bit=make("Frame",{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),
			BackgroundColor3=tint,BorderSizePixel=0,Rotation=rotation or 0},root)
		bit:SetAttribute("TintIcon",true)
		if round then corner(bit,round) end
		return bit
	end
	if kind=="Collection" then
		mark(0.18,0.28,0.64,0.63,4);mark(0.32,0.08,0.36,0.12,3)
	elseif kind=="Food" then
		mark(0.2,0.32,0.62,0.6,8);mark(0.52,0.09,0.12,0.26,2,-20);mark(0.65,0.09,0.24,0.13,4,-24)
	elseif kind=="Sell" then
		mark(0.12,0.64,0.76,0.19,5);mark(0.2,0.39,0.6,0.18,5);mark(0.31,0.14,0.39,0.18,5)
	elseif kind=="Index" then
		mark(0.08,0.14,0.37,0.72,3,-3);mark(0.55,0.14,0.37,0.72,3,3)
		mark(0.47,0.13,0.06,0.76,1)
	elseif kind=="Garden" then
		mark(0.25,0.52,0.53,0.36,4);mark(0.2,0.49,0.63,0.1,3)
		mark(0.48,0.18,0.09,0.38,2);mark(0.2,0.19,0.29,0.16,5,22);mark(0.57,0.1,0.28,0.16,5,-22)
	elseif kind=="Gear" then
		mark(0.46,0.07,0.12,0.6,3,-28);mark(0.17,0.65,0.64,0.2,8);mark(0.54,0.1,0.25,0.12,2,-28)
	else
		mark(0.19,0.19,0.62,0.62,10);mark(0.42,0.04,0.16,0.25,2);mark(0.42,0.71,0.16,0.25,2)
	end
	return root
end
local function previewStage(parent,tint,position,size)
	local stage=make("Frame",{Name="SculptureStage",Position=position,Size=size,BackgroundColor3=tint:Lerp(C.paper,0.9),BorderSizePixel=0,ClipsDescendants=true},parent)
	corner(stage,12)
	stroke(stage,tint:Lerp(C.line,0.65),0.65)
	local halo=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.46),Size=UDim2.fromScale(0.78,0.82),BackgroundColor3=tint,BackgroundTransparency=0.87,BorderSizePixel=0},stage)
	corner(halo,200)
	local ground=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.86),Size=UDim2.fromScale(0.48,0.07),BackgroundColor3=C.bg,BackgroundTransparency=0.9,BorderSizePixel=0},stage)
	corner(ground,100)
	return stage
end
local function landscape(parent,world,position,size)
	local stage=make("Frame",{Position=position,Size=size,BackgroundColor3=world.color:Lerp(C.paper,0.68),BorderSizePixel=0,ClipsDescendants=true},parent)
	corner(stage,12)
	local function block(x,y,w,h,color,radius,rotation)
		local piece=make("Frame",{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=color,BorderSizePixel=0,Rotation=rotation or 0},stage)
		if radius then corner(piece,radius) end
		return piece
	end
	block(0.72,0.12,0.14,0.2,world.id=="Cosmic" and C.paper or C.honey,100)
	local stone=world.id=="Meadow" and Color3.fromRGB(177,190,160) or world.id=="Dunes" and Color3.fromRGB(183,127,86) or Color3.fromRGB(125,161,169)
	local distant=world.color:Lerp(stone,0.62)
	block(-0.15,0.42,0.82,0.9,distant,100,-8)
	block(0.45,0.3,0.82,0.95,stone,35,12)
	local ground=world.id=="Meadow" and Color3.fromRGB(159,188,127) or world.id=="Dunes" and Color3.fromRGB(216,175,116) or Color3.fromRGB(148,192,184)
	block(0,0.7,1,0.4,ground)
	block(0.25,0.77,0.5,0.17,world.id=="Cosmic" and Color3.fromRGB(207,223,213) or Color3.fromRGB(238,215,166),6)
	if world.id=="Meadow" then
		-- Woodland terraces and the brook give this postcard its own profile.
		block(0.61,0.61,0.32,0.1,Color3.fromRGB(120,163,107),9)
		block(0.69,0.52,0.22,0.11,Color3.fromRGB(143,178,119),8)
		block(0.77,0.38,0.028,0.32,Color3.fromRGB(182,221,219),4)
		block(0.69,0.67,0.23,0.07,Color3.fromRGB(139,194,191),20)
		for i=1,3 do
			local x=0.05+(i-1)*0.1
			block(x+0.035,0.56,0.025,0.23,C.gold,2)
			block(x,0.4,0.1,0.25,C.green,20)
		end
	elseif world.id=="Dunes" then
		-- Layered mesa silhouettes frame the desert arch and canyon floor.
		for _,x in ipairs({0.03,0.79}) do
			block(x,0.38,0.18,0.34,Color3.fromRGB(183,123,80),5)
			block(x-0.01,0.36,0.2,0.055,Color3.fromRGB(218,165,109),3)
			block(x,0.5,0.18,0.026,Color3.fromRGB(235,185,126),1)
			block(x,0.62,0.18,0.025,Color3.fromRGB(150,99,70),1)
		end
		block(0.58,0.42,0.04,0.25,C.paper,1);block(0.7,0.42,0.04,0.25,C.paper,1);block(0.58,0.39,0.16,0.05,C.paper,1)
		block(0.24,0.61,0.027,0.13,C.green,3);block(0.22,0.64,0.055,0.025,C.green,2)
	else
		-- A dark geode grotto sits above the sheltered pool and lilac spires.
		block(0.6,0.4,0.34,0.3,Color3.fromRGB(107,149,162),25)
		block(0.67,0.48,0.2,0.22,Color3.fromRGB(60,94,111),20)
		block(0.75,0.5,0.025,0.16,Color3.fromRGB(176,210,225),2,16)
		block(0.61,0.66,0.34,0.2,Color3.fromRGB(89,181,190),100)
		block(0.66,0.69,0.24,0.08,Color3.fromRGB(168,227,221),100)
		for i=1,5 do
			local x=0.035+i*0.07
			block(x,0.59-(i%2)*0.14,0.045,0.24,Color3.fromRGB(195,177,227),3,18)
			block(x+0.01,0.59-(i%2)*0.14,0.012,0.23,Color3.fromRGB(231,224,251),1,18)
		end
	end
	return stage
end

local function money(value)
	value = tonumber(value) or 0
	for _, unit in ipairs({{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do
		if value >= unit[1] then return string.format("%.1f%s", value / unit[1], unit[2]) end
	end
	return string.format("%d", math.floor(value))
end
local function seconds(value)
	value = math.max(0, math.ceil(value))
	return string.format("%d:%02d", math.floor(value / 60), value % 60)
end
local function now() return workspace:GetServerTimeNow() end
local function find(list, id)
	for _, item in ipairs(list) do if item.id == id then return item end end
	return nil
end
local function contains(list, id)
	for _, item in ipairs(list or {}) do if item == id then return true end end
	return false
end
local function selected()
	for _, brainrot in ipairs(state and state.brainrots or {}) do
		if brainrot.uid == selectedUid then return brainrot end
	end
	return nil
end
local function rarity(id)
	return find(Config.Rarities, id) or {name = tostring(id), color = C.muted}
end

local hud = make("Frame", {Name="WalletHud", Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 304, 0, 96),
	BackgroundColor3 = C.panel, BorderSizePixel = 0}, screen)
corner(hud, 18)
stroke(hud, C.line, 0.2)
label(hud, "Brainrot Bloom", 12, C.green, {Position = UDim2.fromOffset(18, 11), Size = UDim2.new(1, -98, 0, 18), Font=Enum.Font.BuilderSansMedium})
local coinSeal=make("Frame",{Position=UDim2.fromOffset(17,35),Size=UDim2.fromOffset(28,28),BackgroundColor3=C.honey,BorderSizePixel=0},hud)
corner(coinSeal,14)
stroke(coinSeal,C.gold,0.6)
icon(coinSeal,"Sell",C.gold,UDim2.fromOffset(7,6),UDim2.fromOffset(14,16))
local coinsLabel = label(hud, "Loading…", 27, C.text, {Name="WalletValue",Position = UDim2.fromOffset(54, 31), Size = UDim2.new(1, -132, 0, 34), Font = Enum.Font.BuilderSansBold,TextTruncate=Enum.TextTruncate.AtEnd})
make("Frame",{Position=UDim2.fromOffset(18,66),Size=UDim2.new(1,-36,0,1),BackgroundColor3=C.line,BackgroundTransparency=0.35,BorderSizePixel=0},hud)
local incomeLabel = label(hud, "Your garden is growing", 13, C.green, {Position = UDim2.fromOffset(18, 69), Size = UDim2.new(1, -32, 0, 18), TextTruncate=Enum.TextTruncate.AtEnd})
button(hud, "Home", function() request("Teleport", {destination = "Home"}) end,
	{Position = UDim2.new(1, -70, 0, 28), Size = UDim2.fromOffset(54,44), TextSize = 13, BackgroundColor3=C.light})
local helpButton = button(screen, "?", function() openPage("Help") end,
	{AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(44,44), BackgroundColor3 = C.panel, TextSize = 20, ZIndex=10})

-- Navigation sits together on the left. Separate icon and label bounds keep
-- every symbol beside its word, without inherited text padding shifting it.
local nav = make("Frame", {Name="NavigationDock", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0,12,0.5,0),
	Size = UDim2.fromOffset(132,306), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex=4}, screen)
corner(nav, 18)
stroke(nav,C.line,0.2)
local navButtons = {}
local navIcons = {}
local navLabels = {}
for index, page in ipairs({"Collection", "Food", "Sell", "Gear"}) do
	navButtons[page] = button(nav, "", function()
		if page == "Food" or page == "Sell" or page == "Gear" then
			local result = request("Teleport", {destination = page})
			if not result or not result.ok then return end
		end
		openPage(page)
	end, {Name=page.."Navigation",Position=UDim2.fromOffset(6,6+(index-1)*50),Size=UDim2.new(1,-12,0,44),BackgroundColor3=C.panel})
	navButtons[page]:SetAttribute("NavigationPage",page)
	navIcons[page]=icon(navButtons[page],page,C.muted,UDim2.new(0,12,0.5,-9),UDim2.fromOffset(18,18))
	navIcons[page].Name="NavigationIcon"
	navLabels[page]=label(navButtons[page],page,13,C.muted,{Name="NavigationLabel",Position=UDim2.new(0,38,0,0),Size=UDim2.new(1,-46,1,0),Font=Enum.Font.BuilderSansMedium})
end
local journalShortcuts=make("Frame",{Name="JournalShortcuts",Position=UDim2.fromOffset(6,206),Size=UDim2.new(1,-12,0,94),BackgroundTransparency=1},nav)
local journalButtons={}
for index,page in ipairs({"Index","Garden"}) do
	local shortcut=button(journalShortcuts,"",function() openPage(page) end,
		{Name=page.."Shortcut",Position=UDim2.fromOffset(0,(index-1)*50),Size=UDim2.new(1,0,0,44),BackgroundColor3=C.panel})
	journalButtons[page]=shortcut
	shortcut:SetAttribute("ShortcutPage",page)
	local symbol=icon(shortcut,page,C.green,UDim2.new(0,12,0.5,-9),UDim2.fromOffset(18,18))
	symbol.Name="ShortcutIcon"
	label(shortcut,page,14,C.text,{Name="ShortcutLabel",Position=UDim2.new(0,38,0,0),Size=UDim2.new(1,-46,1,0),Font=Enum.Font.BuilderSansMedium})
end
local digButton = button(screen, "Dig  ·  E", function() startDig() end,
	{Name="DetectorDig",Visible=false,AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0, 176, 0, 48),
		BackgroundColor3 = C.bg, TextColor3 = C.paper, TextSize = 17})
local detectorLabel = label(screen, "Walk into a sand pit to search", 13, C.paper,
	{Name="ExpeditionStatus",Visible=false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.new(0.9, 0, 0, 30),
		BackgroundColor3=C.bg, BackgroundTransparency=0.12, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate=Enum.TextTruncate.AtEnd})
make("UISizeConstraint",{MaxSize=Vector2.new(470,30)},detectorLabel)
corner(detectorLabel,15)
make("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},detectorLabel)

-- Owning a detector does not mean it is in the character's hand. Follow the
-- actual Tool parent and its replicated marker, including resets and swaps.
local detectorCharacter=nil
local detectorConnections={}
local detectorChildConnections={}
local function detectorEquipped()
	local character=player.Character
	if not character or character~=detectorCharacter then return false end
	local humanoid=character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health<=0 then return false end
	for _,child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("BrainrotDetector")==true then return true end
	end
	return false
end
local function syncDetectorUI()
	local equipped=detectorEquipped()
	screen:SetAttribute("DetectorEquipped",equipped)
	local show=equipped and activePage==nil and capture==nil
	digButton.Visible=show
	detectorLabel.Visible=show
end
local function stopWatchingDetector()
	for _,connection in detectorConnections do connection:Disconnect() end
	for _,connection in detectorChildConnections do connection:Disconnect() end
	table.clear(detectorConnections)
	table.clear(detectorChildConnections)
	detectorCharacter=nil
end
local function watchDetectorCharacter(character)
	stopWatchingDetector()
	detectorCharacter=character
	local function observeChild(child)
		if detectorCharacter~=character then return end
		if child:IsA("Tool") then
			detectorChildConnections[child]=child:GetAttributeChangedSignal("BrainrotDetector"):Connect(syncDetectorUI)
		elseif child:IsA("Humanoid") then
			detectorChildConnections[child]=child.Died:Connect(syncDetectorUI)
		end
		syncDetectorUI()
	end
	table.insert(detectorConnections,character.ChildAdded:Connect(observeChild))
	table.insert(detectorConnections,character.ChildRemoved:Connect(function(child)
		local connection=detectorChildConnections[child]
		if connection then connection:Disconnect();detectorChildConnections[child]=nil end
		syncDetectorUI()
	end))
	for _,child in character:GetChildren() do observeChild(child) end
	syncDetectorUI()
end
player.CharacterAdded:Connect(watchDetectorCharacter)
player.CharacterRemoving:Connect(function(character)
	if detectorCharacter==character then stopWatchingDetector();syncDetectorUI() end
end)
if player.Character then watchDetectorCharacter(player.Character) else syncDetectorUI() end

local shade = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.42,
	Visible = false, BorderSizePixel = 0, Active = true, ZIndex=5}, screen)
local panel = make("Frame", {Name="JournalPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.49),
	Size = UDim2.new(0.94, 0, 0.72, 0), BackgroundColor3 = C.panel, BorderSizePixel = 0}, shade)
make("UISizeConstraint", {MaxSize = Vector2.new(900, 720)}, panel)
corner(panel, 20)
stroke(panel, C.line,0.2)
label(panel,"FIELD JOURNAL",11,C.green,{Position=UDim2.fromOffset(22,12),Size=UDim2.new(1,-100,0,18),Font=Enum.Font.BuilderSansMedium})
local title = label(panel, "Collection", 26, C.text,
	{Name="JournalTitle",Position = UDim2.new(0, 22, 0, 31), Size = UDim2.new(1, -100, 0, 30), Font = Enum.Font.BuilderSansBold, TextScaled=true,TextTruncate = Enum.TextTruncate.AtEnd})
make("UITextSizeConstraint",{MinTextSize=18,MaxTextSize=26},title)
local subtitle = label(panel, "", 13, C.muted,
	{Position = UDim2.new(0, 22, 0, 64), Size = UDim2.new(1, -44, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd})
button(panel, "×", function() openPage(nil) end,
	{Position = UDim2.new(1, -62, 0, 22), Size = UDim2.new(0, 42, 0, 42), BackgroundColor3 = C.light})
make("Frame",{Position=UDim2.new(0,22,0,94),Size=UDim2.new(1,-44,0,1),BackgroundColor3=C.line,BorderSizePixel=0},panel)
local body = make("ScrollingFrame", {Position = UDim2.new(0, 12, 0, 104), Size = UDim2.new(1, -24, 1, -116),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.green,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y}, panel)
padding(body, 8)
vertical(body, 10)

local toast = label(screen, "", 15, C.paper, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 102),
	Size = UDim2.new(0.88, 0, 0, 52), BackgroundColor3 = C.bg, BackgroundTransparency = 0.05,
	TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Visible = false, ZIndex = 20})
make("UISizeConstraint", {MaxSize = Vector2.new(540, 70)}, toast)
corner(toast, 14)
padding(toast, 10)
local toastVersion = 0
local function notify(text, kind)
	toastVersion += 1
	local version = toastVersion
	toast.Text = tostring(text)
	toast.TextColor3 = kind == "error" and C.alert or C.paper
	toast.Visible = true
	task.delay(4, function() if version == toastVersion then toast.Visible = false end end)
end

local function variantCaption(id)
	local finish=Config.variant(id)
	return finish.name.." · "..tostring(finish.multiplier).."x income"
end
local function brainrotName(brainrot)
	local finish=Config.variant(brainrot.variant)
	return (finish.id~="Normal" and finish.name.." " or "")..brainrot.name
end
local function variantTint(id, rarityId)
	local finish=Config.variant(id)
	return finish.id=="Normal" and rarity(rarityId).color or finish.color
end
local function finishBadge(parent,id,position,size)
	local finish=Config.variant(id)
	local field=badge(parent,variantCaption(id),finish.color,position,size)
	field.Name="VariantBadge";field:SetAttribute("Variant",finish.id)
	field.TextTruncate=Enum.TextTruncate.AtEnd
	return field
end
local function viewport(parent, specId, size, pos, options)
	options=options or {}
	local spec = find(Config.Creatures, specId)
	if not spec then return end
	local frame = make("ViewportFrame", {Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(205, 220, 210), LightColor = Color3.fromRGB(255, 248, 219),
		LightDirection = Vector3.new(-1, -1, -2)}, parent)
	frame:SetAttribute("Silhouette",options.silhouette==true)
	frame:SetAttribute("Variant",Config.variant(options.variant).id)
	local world = make("WorldModel", {}, frame)
	local ok, model = pcall(CreatureFactory.create, spec, 1, Config.variant(options.variant).id)
	if not ok or not model then return end
	if options.silhouette then
		for _,object in ipairs(model:GetDescendants()) do
			if object:IsA("BasePart") then
				object.Color=C.bg
				object.Material=Enum.Material.SmoothPlastic
			elseif object:IsA("PointLight") or object:IsA("ParticleEmitter") then
				object:Destroy()
			end
		end
	end
	model.Parent = world
	model:PivotTo(CFrame.new())
	local cf, bounds = model:GetBoundingBox()
	local camera=make("Camera",{FieldOfView=35},frame)
	local direction=Vector3.new(0.65,0.35,-1.75)
	direction=direction/direction.Magnitude
	local function fitCamera()
		local pixels=frame.AbsoluteSize
		local aspect=math.max(0.2,pixels.X/math.max(1,pixels.Y))
		local halfFov=math.atan(math.tan(math.rad(35/2))*math.min(1,aspect))
		local distance=(bounds.Magnitude/2)/math.sin(halfFov)*1.05
		camera.CFrame=CFrame.lookAt(cf.Position+direction*distance,cf.Position)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCamera)
	fitCamera()
	frame.CurrentCamera = camera
	if not options.static then table.insert(viewports, {model = model, base = model:GetPivot()}) end
	return frame
end

local function updateHud()
	if not state then return end
	coinsLabel.Text = "$ " .. money(state.coins)
	incomeLabel.Text = "+$" .. money(state.income) .. " / sec  •  " .. tostring(#(state.brainrots or {})) .. " brainrots"
	local d = find(Config.Detectors, state.detector)
	local w = find(Config.Worlds, state.world)
	detectorLabel.Text = (d and d.name or "Detector") .. "  /  " .. (w and w.name or "Meadow")
end

-- Coins tick continuously; rebuilding every card on each income tick would
-- interrupt touch input and needlessly recreate the 3D models.
local function pageSignature()
	if not state then return "loading" end
	local values = {tostring(state.detector), tostring(state.activeBrainrot), tostring(state.rotationEnds)}
	for _, id in ipairs(state.ownedDetectors or {}) do table.insert(values, id) end
	for _, id in ipairs(state.unlockedWorlds or {}) do table.insert(values, id) end
	for _,id in ipairs(state.discoveredIds or {}) do table.insert(values,"discovered:"..id) end
	for _,spec in ipairs(Config.Creatures) do
		local finishes=(state.discoveredVariants or {})[spec.id] or {}
		for _,finish in ipairs(Config.Variants) do
			if finishes[finish.id]==true then table.insert(values,"finish:"..spec.id..":"..finish.id) end
		end
	end
	if state.garden then
		table.insert(values,"garden:"..tostring(state.garden.id))
		for slot,uid in ipairs(state.garden.slots or {}) do table.insert(values,"slot:"..slot..":"..uid) end
	end
	for _, brainrot in ipairs(state.brainrots or {}) do
		table.insert(values, table.concat({brainrot.uid, brainrot.variant or "Normal", brainrot.level, brainrot.xp, brainrot.income,
			brainrot.growthBoostUntil or 0, brainrot.incomeBoostUntil or 0,
			tostring((brainrot.growthBoostUntil or 0) > now()), tostring((brainrot.incomeBoostUntil or 0) > now())}, ":"))
	end
	for _, food in ipairs(Config.Foods) do table.insert(values, food.id .. ":" .. tostring((state.foods or {})[food.id] or 0)) end
	for _, slot in ipairs(state.stock or {}) do table.insert(values, slot.id .. ":" .. slot.remaining) end
	return table.concat(values, "|")
end

request = function(action, payload)
	local ok, result = pcall(function() return Action:InvokeServer(action, payload or {}) end)
	if not ok then notify("Connection interrupted. Please try again.", "error"); return nil end
	if type(result) ~= "table" then notify("The server could not complete that action.", "error"); return nil end
	if result.state then state = result.state; updateHud() end
	if result.message and action ~= "TapDig" then notify(result.message, result.ok and "success" or "error") end
	return result
end

local function perform(action, payload)
	if busy then return end
	busy = true
	local result = request(action, payload)
	busy = false
	if activePage then renderPage() end
	return result
end
local function empty(text)
	local f = card(body, 112)
	label(f, text, 15, C.muted, {Position = UDim2.new(0, 20, 0, 15), Size = UDim2.new(1, -40, 1, -30), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
end
local function smallTag(parent, text, color, pos, width)
	local tag = label(parent, text, 10, readable(color or C.green), {Position = pos, Size = UDim2.new(0, width or 100, 0, 22),
		BackgroundColor3 = C.light, BackgroundTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.BuilderSansBold})
	corner(tag, 6)
	return tag
end

local function collectionPage(sellMode)
	title.Text = sellMode and "Sell a brainrot" or "Your collection"
	subtitle.Text = sellMode and "Choose a creature to review its value before selling." or "Every brainrot earns coins. Pick one to feed and grow."
	if #(state.brainrots or {}) == 0 then
		empty("Your first discovery is waiting beneath the sand. Head to Clover Commons to start collecting.")
		button(body, "Find my first brainrot", function() local result=perform("Teleport",{destination="Meadow"}); if result and result.ok then openPage(nil) end end,
			{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.lime,TextColor3=C.bg})
		return
	end
	local controls=row(body,44)
	local search=make("TextBox",{Size=UDim2.new(0.56,-6,1,0),BackgroundColor3=C.card,TextColor3=C.text,
		PlaceholderText="Search name or finish…",PlaceholderColor3=C.muted,Text=collectionQuery,ClearTextOnFocus=false,
		Font=Enum.Font.BuilderSans,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0},controls)
	corner(search,10); padding(search,10)
	search.FocusLost:Connect(function()
		if search.Text~=collectionQuery then
			collectionQuery=search.Text; collectionPageIndex=1
			task.defer(renderPage)
		end
	end)
	button(controls,"Sort: "..collectionSort,function()
		local options={"Income","Rarity","Level"}
		collectionSort=options[(table.find(options,collectionSort) or 1)%#options+1]
		collectionPageIndex=1; renderPage()
	end,{Position=UDim2.new(0.56,6,0,0),Size=UDim2.new(0.44,-6,1,0),TextSize=13})
	local filters=make("ScrollingFrame",{Size=UDim2.new(1,0,0,46),BackgroundTransparency=1,BorderSizePixel=0,
		AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ScrollBarThickness=0,
		ScrollingDirection=Enum.ScrollingDirection.X},body)
	make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},filters)
	local categories={"All"}
	for _,r in ipairs(Config.Rarities) do table.insert(categories,r.id) end
	for index,id in ipairs(categories) do
		local chosen=collectionFilter==id
		button(filters,id,function() collectionFilter=id; collectionPageIndex=1; renderPage() end,
			{Size=UDim2.new(0,(id=="Uncommon" or id=="Legendary") and 100 or 86,0,38),LayoutOrder=index,
				BackgroundColor3=chosen and C.lime or C.card,TextColor3=chosen and C.bg or C.muted,TextSize=13})
	end
	local list={}
	local ranks={}
	for index,r in ipairs(Config.Rarities) do ranks[r.id]=index end
	for _,b in ipairs(state.brainrots) do
		if (collectionFilter=="All" or b.rarity==collectionFilter) and string.find(string.lower(Config.variant(b.variant).name.." "..b.name),string.lower(collectionQuery),1,true) then table.insert(list,b) end
	end
	table.sort(list,function(a,b)
		local av=collectionSort=="Rarity" and ranks[a.rarity] or collectionSort=="Level" and a.level or a.income
		local bv=collectionSort=="Rarity" and ranks[b.rarity] or collectionSort=="Level" and b.level or b.income
		if av==bv then return a.uid<b.uid end
		return av>bv
	end)
	if #list==0 then empty("No matches. Try a different name or rarity."); return end
	local pages=math.max(1,math.ceil(#list/collectionPageSize))
	collectionPageIndex=math.clamp(collectionPageIndex,1,pages)
	local first=(collectionPageIndex-1)*collectionPageSize+1
	local last=math.min(#list,first+collectionPageSize-1)
	label(body,string.format("%d brainrots  ·  %d/%d collected",#list,#state.brainrots,Config.MaxBrainrots),13,C.muted)
	local columns=cardColumns()
	local gap=12
	local stageHeight=columns==1 and 168 or 126
	local shift=stageHeight-126
	local tileHeight=284+shift
	local grid=row(body,math.ceil((last-first+1)/columns)*(tileHeight+gap)-gap)
	grid.Name="CollectionGrid";grid:SetAttribute("CardColumns",columns)
	make("UIGridLayout",{CellSize=UDim2.new(1/columns,-gap*(columns-1)/columns,0,tileHeight),CellPadding=UDim2.fromOffset(gap,gap),SortOrder=Enum.SortOrder.LayoutOrder},grid)
	for index=first,last do
		local b=list[index]
		local r=rarity(b.rarity)
		local tile=card(grid,tileHeight)
		tile.LayoutOrder=index
		tile:SetAttribute("CollectionUID",b.uid)
		previewStage(tile,variantTint(b.variant,b.rarity),UDim2.fromOffset(10,10),UDim2.new(1,-20,0,stageHeight))
		viewport(tile,b.specId,UDim2.new(1,-12,0,stageHeight),UDim2.fromOffset(6,8),{variant=b.variant})
		finishBadge(tile,b.variant,UDim2.fromOffset(16,stageHeight-18),UDim2.new(1,-32,0,22))
		label(tile,b.name,15,C.text,{Position=UDim2.fromOffset(12,143+shift),Size=UDim2.new(1,-24,0,38),TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,Font=Enum.Font.BuilderSansBold})
		label(tile,r.name.." · Lv "..b.level,12,readable(r.color),{Position=UDim2.fromOffset(12,183+shift),Size=UDim2.new(1,-24,0,18),TextTruncate=Enum.TextTruncate.AtEnd})
		label(tile,"+$"..money(b.income).." / sec",15,C.gold,{Name="IncomeStat",Position=UDim2.fromOffset(12,207+shift),Size=UDim2.new(1,-24,0,20),Font=Enum.Font.BuilderSansMedium,TextTruncate=Enum.TextTruncate.AtEnd})
		button(tile,sellMode and "Review sale" or "Feed & grow",function() selectedUid=b.uid; openPage(sellMode and "SellDetail" or "Detail") end,
			{Position=UDim2.new(0,10,1,-52),Size=UDim2.new(1,-20,0,44),TextSize=13,BackgroundColor3=C.light})
		if state.activeBrainrot==b.uid then
			local border=tile:FindFirstChild("CardBorder");border.Color=C.green;border.Transparency=0.15
			smallTag(tile,"Following",C.green,UDim2.fromOffset(16,16),82)
		end
	end
	if pages>1 then
		local paging=row(body,44)
		button(paging,"Previous",function() collectionPageIndex=math.max(1,collectionPageIndex-1); renderPage(); body.CanvasPosition=Vector2.zero end,
			{Size=UDim2.new(0.32,0,1,0),TextSize=13})
		label(paging,collectionPageIndex.." / "..pages,13,C.muted,{Position=UDim2.new(0.33,0,0,0),Size=UDim2.new(0.34,0,1,0),TextXAlignment=Enum.TextXAlignment.Center})
		button(paging,"Next",function() collectionPageIndex=math.min(pages,collectionPageIndex+1); renderPage(); body.CanvasPosition=Vector2.zero end,
			{Position=UDim2.new(0.68,0,0,0),Size=UDim2.new(0.32,0,1,0),TextSize=13})
	end
end

local function detailPage(sellMode)
	local brainrot = selected()
	if not brainrot then selectedUid = nil; activePage = sellMode and "Sell" or "Collection"; collectionPage(sellMode); return end
	local r = rarity(brainrot.rarity)
	title.Text = brainrotName(brainrot)
	subtitle.Text = r.name .. "  ·  Level " .. brainrot.level .. "  /  +$" .. money(brainrot.income) .. " per second"
	button(body, "‹ Back to collection", function() openPage(sellMode and "Sell" or "Collection") end, {Size = UDim2.new(1, 0, 0, 32), TextSize = 13})
	finishBadge(body,brainrot.variant,UDim2.new(),UDim2.new(1,0,0,30))
	local stacked=body.AbsoluteSize.X<440
	local hero = card(body, stacked and 360 or 204)
	hero.Name="CreatureHero";hero:SetAttribute("Stacked",stacked)
	previewStage(hero,variantTint(brainrot.variant,brainrot.rarity),UDim2.fromOffset(12,12),stacked and UDim2.new(1,-24,0,150) or UDim2.new(0.48,-12,1,-24))
	viewport(hero,brainrot.specId,stacked and UDim2.new(1,-16,0,150) or UDim2.new(0.48,-8,1,-16),UDim2.fromOffset(8,8),{variant=brainrot.variant})
	local sx,ox,sw,ow,top=stacked and 0 or 0.5,stacked and 16 or 8,stacked and 1 or 0.5,stacked and -32 or -24,stacked and 176 or 17
	label(hero,"Level "..brainrot.level.." / "..Config.MaxLevel,18,C.text,{Name="HeroLevel",Position=UDim2.new(sx,ox,0,top),Size=UDim2.new(sw,ow,0,28),Font=Enum.Font.BuilderSansBold})
	local maxed=brainrot.level>=Config.MaxLevel
	label(hero,maxed and "Fully grown" or (tostring(math.floor(brainrot.xp or 0)).." / "..tostring(brainrot.xpNeeded or Config.xpNeeded(brainrot.level)).." XP"),13,C.muted,
		{Position=UDim2.new(sx,ox,0,top+32),Size=UDim2.new(sw,ow,0,21)})
	local track=make("Frame",{Name="GrowthTrack",Position=UDim2.new(sx,ox,0,top+62),Size=UDim2.new(sw,ow,0,7),BackgroundColor3=C.light,BorderSizePixel=0},hero)
	corner(track,4)
	local fill=make("Frame",{Size=UDim2.new(maxed and 1 or math.clamp((brainrot.xp or 0)/math.max(1,brainrot.xpNeeded or Config.xpNeeded(brainrot.level)),0,1),0,1,0),BackgroundColor3=readable(r.color),BorderSizePixel=0},track)
	corner(fill,4)
	local incomeFactor=(brainrot.incomeBoostUntil or 0)>now() and 2 or 1
	local nextIncome=Config.income(brainrot.specId,math.min(Config.MaxLevel,brainrot.level+1),brainrot.variant)*incomeFactor
	label(hero,maxed and "A perfect little earner." or ("Next level: $"..money(nextIncome).." / sec"),13,C.gold,
		{Position=UDim2.new(sx,ox,0,top+81),Size=UDim2.new(sw,ow,0,34),TextWrapped=true})
	button(hero,state.activeBrainrot==brainrot.uid and "Following you" or "Set as companion",function() perform("EquipBrainrot",{uid=brainrot.uid}) end,
		{Position=UDim2.new(sx,ox,0,top+126),Size=UDim2.new(sw,ow,0,44),TextSize=13,BackgroundColor3=C.light})
	if not sellMode then
		button(body,"Place in garden",function()
			selectedGardenUid=brainrot.uid
			local slots=state.garden and state.garden.slots or {}
			local current=table.find(slots,brainrot.uid)
			selectedGardenSlot=current or table.find(slots,"") or 1
			openPage("Garden")
		end,{Size=UDim2.new(1,0,0,44),BackgroundColor3=C.light})
	end
	if sellMode then
		label(body, "Sold creatures and their levels cannot be recovered.", 12, C.muted, {Size = UDim2.new(1, 0, 0, 42), TextWrapped = true})
		local sale = brainrot.sellValue or brainrot.value or Config.sellValue(brainrot.specId, brainrot.level, brainrot.variant)
		button(body, sale and ("Sell for $" .. money(sale)) or "Sell this brainrot", function()
			if activePage == "SellConfirm" then
				local result = perform("Sell", {uid = brainrot.uid})
				if result and result.ok then selectedUid = nil; openPage("Sell") end
			else activePage = "SellConfirm"; renderPage() end
		end, {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.red, TextColor3 = C.paper})
		if activePage == "SellConfirm" then
			label(body, "Tap SELL again to confirm this permanent sale.", 13, C.red, {Size = UDim2.new(1, 0, 0, 42), TextWrapped = true})
		end
		return
	end
	local growthTime = (brainrot.growthBoostUntil or 0) - now()
	local incomeTime = (brainrot.incomeBoostUntil or 0) - now()
	if growthTime > 0 or incomeTime > 0 then
		local status = label(body, (growthTime > 0 and "2x growth: " .. seconds(growthTime) .. "   " or "") .. (incomeTime > 0 and "2x income: " .. seconds(incomeTime) or ""),
			12, C.green, {Size = UDim2.new(1, 0, 0, 26)})
		status:SetAttribute("GrowthUntil", brainrot.growthBoostUntil or 0)
		status:SetAttribute("IncomeUntil", brainrot.incomeBoostUntil or 0)
	end
	label(body, "Feed to grow", 12, C.green)
	local foodFound = false
	for _, food in ipairs(Config.Foods) do
		local owned = (state.foods or {})[food.id] or 0
		if owned > 0 then
			foodFound = true
			local f = card(body, 126)
			label(f, food.name .. "  x" .. owned, 15, C.text, {Position = UDim2.new(0, 13, 0, 9), Size = UDim2.new(1, -26, 0, 23)})
			label(f, "+" .. food.xp .. " XP each" .. (growthTime > 0 and "  (2x active!)" or ""), 11, C.muted,
				{Position = UDim2.new(0, 13, 0, 34), Size = UDim2.new(1, -26, 0, 18)})
			button(f, "Feed one", function() perform("Feed", {uid = brainrot.uid, foodId = food.id, quantity = 1}) end,
				{Position = UDim2.new(0, 12, 0, 61), Size = UDim2.new(0.48, -12, 0, 44), BackgroundColor3 = C.lime, TextColor3 = C.bg, TextSize = 13})
			local feedQuantity = math.min(owned, 100)
			button(f, owned > 100 and "Feed 100" or ("Feed all (" .. owned .. ")"), function() perform("Feed", {uid = brainrot.uid, foodId = food.id, quantity = feedQuantity}) end,
				{Position = UDim2.new(0.5, 1, 0, 61), Size = UDim2.new(0.5, -13, 0, 44), TextSize = 13})
		end
	end
	if not foodFound then empty("Your food bag is empty. Visit the rotating food shop to buy snacks.") end
	button(body, "Visit food shop", function() local result = perform("Teleport", {destination = "Food"}); if result and result.ok then openPage("Food") end end,
		{Size = UDim2.new(1, 0, 0, 40)})
	label(body, "Five-minute boosts · this brainrot", 11, C.green)
	for _, kind in ipairs({"Growth", "Income"}) do
		local boost = Config.Boosts[kind]
		button(body, "2x " .. kind .. "  /  $" .. money(boost.price), function() perform("BuyBoost", {uid = brainrot.uid, kind = kind}) end,
			{Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.light})
	end
end

local function foodPage()
	title.Text = "Food market"
	subtitle.Text = "Fresh random stock every 5 minutes. Shared rotation, personal stock."
	local qty = row(body, 44)
	label(qty, "Buy quantity", 11, C.muted, {Size = UDim2.new(0.4, 0, 1, 0)})
	for index, amount in ipairs({1, 5, 10}) do
		button(qty, tostring(amount), function() chosenQuantity = amount; renderPage() end,
			{Position = UDim2.new(0.4 + (index - 1) * 0.2, 2, 0, 2), Size = UDim2.new(0.2, -5, 1, -4),
				BackgroundColor3 = chosenQuantity == amount and C.lime or C.light, TextColor3 = chosenQuantity == amount and C.bg or C.text})
	end
	local rotation=label(body,"Restocking…",13,C.green,{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.light,TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.BuilderSansMedium})
	rotation.Name="RotationCountdown"
	corner(rotation,10)
	local stockMap = {}
	for _, slot in ipairs(state.stock or {}) do stockMap[slot.id] = slot.remaining end
	for _, food in ipairs(Config.Foods) do
		local remaining = stockMap[food.id]
		if remaining ~= nil then
			local f=card(body,148)
			local token=make("Frame",{Position=UDim2.fromOffset(14,14),Size=UDim2.fromOffset(58,58),BackgroundColor3=C.light,BorderSizePixel=0},f)
			corner(token,16)
			label(token,food.emoji or "•",30,C.text,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
			label(f,food.name,16,C.text,{Position=UDim2.fromOffset(84,13),Size=UDim2.new(1,-98,0,36),TextWrapped=true,Font=Enum.Font.BuilderSansMedium})
			badge(f,"+"..food.xp.." XP",C.green,UDim2.fromOffset(84,51),UDim2.fromOffset(116,21))
			label(f,"$"..money(food.price).." each",13,C.gold,{Position=UDim2.fromOffset(84,73),Size=UDim2.new(1,-98,0,20)})
			label(f,remaining.." in stock",13,C.muted,{Position=UDim2.fromOffset(14,99),Size=UDim2.new(0.5,-20,0,18)})
			label(f,"Pantry: "..((state.foods or {})[food.id] or 0),13,C.muted,{Position=UDim2.fromOffset(14,120),Size=UDim2.new(0.5,-20,0,18)})
			local amount=math.min(chosenQuantity,remaining)
			button(f,remaining>0 and ("Buy "..amount.." · $"..money(food.price*amount)) or "Sold out",function()
				if amount>0 then perform("BuyFood",{id=food.id,quantity=amount}) end
			end,{Position=UDim2.new(0.5,0,1,-56),Size=UDim2.new(0.5,-14,0,44),TextSize=13,
				BackgroundColor3=remaining>0 and C.lime or C.light,TextColor3=remaining>0 and C.bg or C.muted})
		end
	end
	if not next(stockMap) then empty("The shop is preparing today's snacks. Try again in a moment.") end
end

local function gearPage()
	title.Text = "Gear workshop"
	subtitle.Text = "Better detectors search faster and unlock rarer finds."
	local tabs = row(body, 42)
	for index, tab in ipairs({"Detectors", "Boosts"}) do
		button(tabs, tab, function() gearTab = tab; renderPage() end,
			{Position = UDim2.new((index - 1) * 0.5, 0, 0, 0), Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundColor3 = gearTab == tab and C.lime or C.light, TextColor3 = gearTab == tab and C.bg or C.text})
	end
	if gearTab == "Boosts" then
		label(body, "Choose exactly which brainrot receives a boost.", 13, C.muted, {Size = UDim2.new(1, 0, 0, 36), TextWrapped = true})
		if #(state.brainrots or {}) == 0 then empty("Capture a brainrot first to use a growth or income boost."); return end
		for _, brainrot in ipairs(state.brainrots) do
			local f = card(body, 122)
			label(f, brainrot.name .. "  /  Lv " .. brainrot.level, 15, readable(rarity(brainrot.rarity).color),
				{Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -24, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd})
			for index, kind in ipairs({"Growth", "Income"}) do
				local boost = Config.Boosts[kind]
				local untilTime = brainrot[string.lower(kind) .. "BoostUntil"] or 0
				local active = untilTime > now()
				button(f, "2x " .. kind .. " / $" .. money(boost.price), function() perform("BuyBoost", {uid = brainrot.uid, kind = kind}) end,
					{Position = UDim2.new((index - 1) * 0.5, 10, 0, 44), Size = UDim2.new(0.5, -15, 0, 39), TextSize = 13, BackgroundColor3 = C.light})
				local status = label(f, active and ("Active  " .. seconds(untilTime - now())) or "Lasts 5 minutes", 10, active and C.green or C.muted,
					{Position = UDim2.new((index - 1) * 0.5, 12, 0, 88), Size = UDim2.new(0.5, -15, 0, 20)})
				if active then status:SetAttribute("BoostUntil", untilTime) end
			end
		end
		return
	end
	for _,detector in ipairs(Config.Detectors) do
		local owned=contains(state.ownedDetectors,detector.id)
		local equipped=state.detector==detector.id
		local f=card(body,206)
		local tint=detector.color or C.green
		local token=make("Frame",{Position=UDim2.fromOffset(14,16),Size=UDim2.fromOffset(74,90),BackgroundColor3=tint:Lerp(C.paper,0.78),BorderSizePixel=0},f)
		corner(token,12)
		icon(token,"Gear",readable(tint),UDim2.fromOffset(13,15),UDim2.fromOffset(48,56))
		label(f,detector.name,17,C.text,{Position=UDim2.fromOffset(102,13),Size=UDim2.new(1,-116,0,38),TextWrapped=true,Font=Enum.Font.BuilderSansBold})
		local ceiling=Config.Rarities[math.min(detector.power,#Config.Rarities)]
		label(f,"Finds through "..ceiling.name,13,readable(ceiling.color),{Position=UDim2.fromOffset(102,56),Size=UDim2.new(1,-116,0,21)})
		label(f,tostring(detector.speed).."s between scans",13,C.muted,{Position=UDim2.fromOffset(102,80),Size=UDim2.new(1,-116,0,21)})
		local w=find(Config.Worlds,detector.world)
		local available=contains(state.unlockedWorlds,detector.world)
		label(f,available and ("Power "..detector.power.." / "..#Config.Rarities) or ("Requires "..(w and w.name or detector.world)),13,available and C.muted or C.red,
			{Position=UDim2.fromOffset(14,116),Size=UDim2.new(1,-28,0,19),TextTruncate=Enum.TextTruncate.AtEnd})
		for rank=1,#Config.Rarities do
			local segment=make("Frame",{Position=UDim2.new((rank-1)/#Config.Rarities,14-(rank-1)*22/#Config.Rarities,0,140),Size=UDim2.new(1/#Config.Rarities,-(28+6*(#Config.Rarities-1))/#Config.Rarities,0,5),
				BackgroundColor3=rank<=detector.power and readable(tint) or C.light,BorderSizePixel=0},f)
			corner(segment,3)
		end
		button(f,equipped and "Equipped" or (owned and "Equip" or ("Buy · $"..money(detector.price))),function()
			if not equipped then perform(owned and "EquipDetector" or "BuyDetector",{id=detector.id}) end
		end,{Position=UDim2.new(0,14,1,-56),Size=UDim2.new(1,-28,0,44),BackgroundColor3=equipped and C.light or C.lime,
			TextColor3=equipped and C.green or C.bg,TextSize=14})
	end
end

local function worldsPage()
	title.Text="Choose a world"
	subtitle.Text="A new landscape, new discoveries. Your next adventure starts here."
	local wide=body.AbsoluteSize.X>=620
	local detector=find(Config.Detectors,state.detector)
	for index,world in ipairs(Config.Worlds) do
		local unlocked=contains(state.unlockedWorlds,world.id)
		local f=card(body,wide and 212 or 302)
		landscape(f,world,UDim2.fromOffset(12,12),wide and UDim2.new(0.36,-12,1,-24) or UDim2.new(1,-24,0,104))
		local xScale,xOffset=wide and 0.38 or 0,wide and 0 or 16
		local top=wide and 16 or 126
		label(f,"EXPEDITION 0"..index,12,C.green,{Position=UDim2.new(xScale,xOffset,0,top),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,18),Font=Enum.Font.BuilderSansMedium})
		label(f,world.name,21,C.text,{Position=UDim2.new(xScale,xOffset,0,top+22),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,30),Font=Enum.Font.BuilderSansBold,TextTruncate=Enum.TextTruncate.AtEnd})
		label(f,world.description or "A landscape of strange little discoveries.",13,C.muted,{Position=UDim2.new(xScale,xOffset,0,top+56),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,36),TextWrapped=true})
		local canDig=detector and detector.power>=world.minPower
		label(f,"Power "..world.minPower.."+ · Up to "..Config.Rarities[world.maxRarity].name,13,canDig and C.green or C.red,
			{Position=UDim2.new(xScale,xOffset,0,top+98),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,20)})
		button(f,unlocked and "Travel to sand pit" or ("Unlock · $"..money(world.unlockCost)),function()
			local result=perform(unlocked and "Teleport" or "UnlockWorld",unlocked and {destination=world.id} or {id=world.id})
			if result and result.ok then openPage(nil) end
		end,{Position=UDim2.new(xScale,xOffset,1,-56),Size=UDim2.new(wide and 0.62 or 1,wide and -16 or -32,0,44),
			BackgroundColor3=unlocked and C.lime or C.light,TextColor3=C.bg,TextSize=14})
	end
end

local function journalLinks(active)
	local links=row(body,44)
	for index,page in ipairs({"Index","Garden"}) do
		button(links,page=="Index" and "Index book" or "My garden",function() openPage(page) end,
			{Position=UDim2.new((index-1)*0.5,0,0,0),Size=UDim2.new(0.5,-5,1,0),
				BackgroundColor3=active==page and C.bg or C.light,TextColor3=active==page and C.paper or C.text})
	end
end

local function discoverySet()
	local discovered={}
	for _,id in ipairs(state.discoveredIds or {}) do discovered[id]=true end
	-- Compatibility while an older saved collection is first migrated.
	for _,brainrot in ipairs(state.brainrots or {}) do discovered[brainrot.specId]=true end
	return discovered
end

local function discoveryHint(spec)
	local rank=table.find(Config.Rarities,find(Config.Rarities,spec.rarity)) or 1
	local world
	for _,entry in ipairs(Config.Worlds) do
		if entry.maxRarity>=rank then world=entry;break end
	end
	return (world and world.name or "Explore the worlds").." · Power "..math.max(rank,world and world.minPower or rank).."+"
end

local function variantDiscoverySet()
	local history={}
	for _,spec in ipairs(Config.Creatures) do
		local saved=(state.discoveredVariants or {})[spec.id] or {}
		local finishes={}
		for _,finish in ipairs(Config.Variants) do if saved[finish.id]==true then finishes[finish.id]=true end end
		history[spec.id]=finishes
	end
	-- Older servers only reported species discoveries; their finds were Normal.
	if state.discoveredVariants==nil then
		for _,id in ipairs(state.discoveredIds or {}) do if history[id] then history[id].Normal=true end end
	end
	for _,brainrot in ipairs(state.brainrots or {}) do
		if history[brainrot.specId] then history[brainrot.specId][Config.variant(brainrot.variant).id]=true end
	end
	return history
end

local function indexPage()
	title.Text="Brainrot index"
	subtitle.Text="Species and their finishes are remembered, even after selling."
	journalLinks("Index")
	local discovered=discoverySet()
	local history=variantDiscoverySet()
	local finish=Config.variant(indexVariant)
	local total,finishCount,allFinishes,totalWeight=0,0,0,0
	local rarityCounts={}
	local ownedCounts={}
	for _,brainrot in ipairs(state.brainrots or {}) do
		if Config.variant(brainrot.variant).id==finish.id then ownedCounts[brainrot.specId]=(ownedCounts[brainrot.specId] or 0)+1 end
	end
	for _,entry in ipairs(Config.Variants) do totalWeight+=entry.weight end
	for _,spec in ipairs(Config.Creatures) do
		if discovered[spec.id] then total+=1;rarityCounts[spec.rarity]=(rarityCounts[spec.rarity] or 0)+1 end
		if history[spec.id][finish.id] then finishCount+=1 end
		for _,entry in ipairs(Config.Variants) do if history[spec.id][entry.id] then allFinishes+=1 end end
	end
	local progress=card(body,105)
	label(progress,total.." / "..#Config.Creatures.." discovered",20,C.text,{Position=UDim2.fromOffset(16,10),Size=UDim2.new(1,-32,0,28),Font=Enum.Font.BuilderSansBold})
	label(progress,allFinishes.." / "..(#Config.Creatures*#Config.Variants).." species finishes found",13,C.muted,{Name="VariantDiscoveryProgress",Position=UDim2.fromOffset(16,42),Size=UDim2.new(1,-32,0,22)})
	local track=make("Frame",{Position=UDim2.fromOffset(16,77),Size=UDim2.new(1,-32,0,8),BackgroundColor3=C.light,BorderSizePixel=0},progress)
	corner(track,4)
	local fill=make("Frame",{Size=UDim2.new(total/#Config.Creatures,0,1,0),BackgroundColor3=C.green,BorderSizePixel=0},track);corner(fill,4)
	local finishes=make("ScrollingFrame",{Name="IndexFinishSelector",Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,BorderSizePixel=0,
		AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X},body)
	make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},finishes)
	for order,entry in ipairs(Config.Variants) do
		local target=button(finishes,entry.name.." "..entry.multiplier.."x",function() indexVariant=entry.id;renderPage() end,
			{Name="IndexFinish"..entry.id,Size=UDim2.fromOffset(118,44),LayoutOrder=order,BackgroundColor3=finish.id==entry.id and entry.color:Lerp(C.paper,0.55) or C.light,TextColor3=readable(entry.color)})
		target:SetAttribute("Variant",entry.id)
	end
	local odds=card(body,88)
	label(odds,variantCaption(finish.id),16,readable(finish.color),{Position=UDim2.fromOffset(16,10),Size=UDim2.new(1,-32,0,24),Font=Enum.Font.BuilderSansBold})
	label(odds,string.format("%g%% of found signals · %d / %d discovered",finish.weight/totalWeight*100,finishCount,#Config.Creatures),13,C.muted,
		{Name="VariantOdds",Position=UDim2.fromOffset(16,38),Size=UDim2.new(1,-32,0,40),TextWrapped=true})
	local chapters=make("ScrollingFrame",{Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,BorderSizePixel=0,
		AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X},body)
	make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},chapters)
	button(chapters,"All rarities",function() indexRarityFilter="All";renderPage() end,
		{Size=UDim2.fromOffset(114,44),LayoutOrder=0,BackgroundColor3=indexRarityFilter=="All" and C.lime or C.light})
	for index,r in ipairs(Config.Rarities) do
		local count=0
		for _,spec in ipairs(Config.Creatures) do if spec.rarity==r.id then count+=1 end end
		button(chapters,r.name.." "..(rarityCounts[r.id] or 0).."/"..count,function() indexRarityFilter=r.id;renderPage() end,
			{Size=UDim2.fromOffset(140,44),LayoutOrder=index,BackgroundColor3=indexRarityFilter==r.id and C.lime or C.light,TextColor3=readable(r.color),TextSize=13})
	end
	local entries={}
	for _,spec in ipairs(Config.Creatures) do if indexRarityFilter=="All" or spec.rarity==indexRarityFilter then table.insert(entries,spec) end end
	local columns=cardColumns()
	local gap=12
	local stageHeight=columns==1 and 156 or 112
	local shift=stageHeight-112
	local tileHeight=264+shift
	local grid=row(body,math.ceil(#entries/columns)*(tileHeight+gap)-gap)
	grid.Name="IndexGrid";grid:SetAttribute("CardColumns",columns)
	make("UIGridLayout",{CellSize=UDim2.new(1/columns,-gap*(columns-1)/columns,0,tileHeight),CellPadding=UDim2.fromOffset(gap,gap),SortOrder=Enum.SortOrder.LayoutOrder},grid)
	for order,spec in ipairs(entries) do
		local known=history[spec.id][finish.id]==true
		local r=rarity(spec.rarity)
		local tile=card(grid,tileHeight);tile.LayoutOrder=order
		tile:SetAttribute("IndexSpecies",spec.id);tile:SetAttribute("IndexVariant",finish.id)
		tile:SetAttribute("Discovered",known)
		previewStage(tile,known and variantTint(finish.id,spec.rarity) or C.line,UDim2.fromOffset(10,10),UDim2.new(1,-20,0,stageHeight))
		viewport(tile,spec.id,UDim2.new(1,-12,0,stageHeight),UDim2.fromOffset(6,8),{silhouette=not known,static=true,variant=finish.id})
		label(tile,discovered[spec.id] and spec.name or "???",15,discovered[spec.id] and C.text or C.muted,{Position=UDim2.fromOffset(12,129+shift),Size=UDim2.new(1,-24,0,38),TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,Font=Enum.Font.BuilderSansBold})
		label(tile,r.name.." · "..finish.name..(known and "" or " missing"),12,readable(known and variantTint(finish.id,spec.rarity) or r.color),{Position=UDim2.fromOffset(12,169+shift),Size=UDim2.new(1,-24,0,20),TextTruncate=Enum.TextTruncate.AtEnd})
		label(tile,discoveryHint(spec),12,C.muted,{Position=UDim2.fromOffset(12,192+shift),Size=UDim2.new(1,-24,0,36),TextWrapped=true})
		label(tile,known and ("$"..money(Config.income(spec.id,1,finish.id)).." / sec base · Own "..(ownedCounts[spec.id] or 0)) or "Catch this finish to reveal",12,known and C.gold or C.muted,
			{Position=UDim2.fromOffset(12,234+shift),Size=UDim2.new(1,-24,0,20),TextTruncate=Enum.TextTruncate.AtEnd})
	end
end

local function gardenPage()
	title.Text="My garden"
	subtitle.Text="Arrange six displays. Your whole collection keeps earning income."
	journalLinks("Garden")
	local garden=state.garden
	if not garden or not garden.id then empty("Your personal garden is being prepared. Try again in a moment.");return end
	local slots=garden.slots or {}
	local capacity=garden.capacity or Config.GardenSlots or 6
	selectedGardenSlot=math.clamp(selectedGardenSlot,1,capacity)
	local byUid={}
	for _,brainrot in ipairs(state.brainrots or {}) do byUid[brainrot.uid]=brainrot end
	local occupied=0
	for _,uid in ipairs(slots) do if byUid[uid] then occupied+=1 end end
	local summary=card(body,85)
	label(summary,string.format("Garden %02d",garden.id),21,C.text,{Position=UDim2.fromOffset(16,10),Size=UDim2.new(1,-32,0,29),Font=Enum.Font.BuilderSansBold})
	label(summary,occupied.." / "..capacity.." displays · A home for your discoveries",13,C.muted,{Position=UDim2.fromOffset(16,46),Size=UDim2.new(1,-32,0,24),TextTruncate=Enum.TextTruncate.AtEnd})
	button(body,"Travel to my garden",function()
		local result=perform("Teleport",{destination="Garden"})
		if result and result.ok then openPage(nil) end
	end,{Size=UDim2.new(1,0,0,46),BackgroundColor3=C.lime,TextColor3=C.bg})
	label(body,"Choose a display slot",14,C.green,{Font=Enum.Font.BuilderSansMedium})
	local selectors=row(body,98)
	make("UIGridLayout",{CellSize=UDim2.new(1/3,-6,0,44),CellPadding=UDim2.fromOffset(9,8),SortOrder=Enum.SortOrder.LayoutOrder},selectors)
	for slot=1,capacity do
		local current=byUid[slots[slot]]
		local selected=selectedGardenSlot==slot
		local b=button(selectors,"Slot "..slot,function() selectedGardenSlot=slot;selectedGardenUid=nil;renderPage() end,
			{LayoutOrder=slot,BackgroundColor3=selected and C.bg or C.light,TextColor3=selected and C.paper or C.text,TextSize=13})
		b:SetAttribute("Occupied",current~=nil)
	end
	local displayed=byUid[slots[selectedGardenSlot]]
	local stacked=body.AbsoluteSize.X<440
	local hero=card(body,displayed and stacked and 326 or 170)
	hero.Name="GardenHero";hero:SetAttribute("Stacked",displayed~=nil and stacked)
	if displayed then
		previewStage(hero,variantTint(displayed.variant,displayed.rarity),UDim2.fromOffset(12,12),stacked and UDim2.new(1,-24,0,140) or UDim2.new(0.48,-12,1,-24))
		viewport(hero,displayed.specId,stacked and UDim2.new(1,-16,0,140) or UDim2.new(0.48,-8,1,-16),UDim2.fromOffset(8,8),{variant=displayed.variant})
		local sx,ox,sw,ow,top=stacked and 0 or 0.5,stacked and 16 or 8,stacked and 1 or 0.5,stacked and -32 or -24,stacked and 164 or 15
		local gardenTitle=label(hero,brainrotName(displayed),16,C.text,{Name="GardenHeroTitle",Position=UDim2.new(sx,ox,0,top),Size=UDim2.new(sw,ow,0,48),TextWrapped=true,TextScaled=true,TextTruncate=Enum.TextTruncate.AtEnd,Font=Enum.Font.BuilderSansMedium})
		make("UITextSizeConstraint",{MinTextSize=14,MaxTextSize=16},gardenTitle)
		label(hero,variantCaption(displayed.variant).."\nLv "..displayed.level.." · $"..money(displayed.income).." / sec",13,C.gold,{Name="GardenHeroIncome",Position=UDim2.new(sx,ox,0,top+51),Size=UDim2.new(sw,ow,0,stacked and 38 or 42),TextWrapped=true})
		button(hero,"Clear slot",function() perform("GardenClear",{slot=selectedGardenSlot}) end,
			{Position=UDim2.new(sx,ox,1,-56),Size=UDim2.new(sw,ow,0,44),TextSize=13})
	else
		label(hero,"Slot "..selectedGardenSlot.." is empty",19,C.text,{Position=UDim2.fromOffset(16,20),Size=UDim2.new(1,-32,0,32),Font=Enum.Font.BuilderSansMedium})
		label(hero,"Choose one of your brainrots below to make this display its home.",14,C.muted,{Position=UDim2.fromOffset(16,65),Size=UDim2.new(1,-32,0,72),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	end
	label(body,"Choose a brainrot for slot "..selectedGardenSlot,14,C.green,{Font=Enum.Font.BuilderSansMedium})
	if #(state.brainrots or {})==0 then empty("Capture your first brainrot to start filling your garden.");return end
	for _,brainrot in ipairs(state.brainrots) do
		local currentSlot=table.find(slots,brainrot.uid)
		local f=card(body,112)
		if selectedGardenUid==brainrot.uid then stroke(f,C.green,0.1) end
		label(f,brainrotName(brainrot),15,C.text,{Position=UDim2.fromOffset(14,10),Size=UDim2.new(1,-154,0,42),TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,Font=Enum.Font.BuilderSansMedium})
		label(f,Config.variant(brainrot.variant).multiplier.."x · Lv "..brainrot.level.." · $"..money(brainrot.income).." / sec",13,C.gold,{Position=UDim2.fromOffset(14,57),Size=UDim2.new(1,-154,0,20),TextTruncate=Enum.TextTruncate.AtEnd})
		label(f,currentSlot and ("Displayed in slot "..currentSlot) or "Ready for your garden",12,C.muted,{Position=UDim2.fromOffset(14,82),Size=UDim2.new(1,-154,0,18),TextTruncate=Enum.TextTruncate.AtEnd})
		local here=currentSlot==selectedGardenSlot
		button(f,here and "Already here" or (currentSlot and "Move here" or "Place here"),function()
			if not here then selectedGardenUid=brainrot.uid;perform("GardenAssign",{uid=brainrot.uid,slot=selectedGardenSlot}) end
		end,{Position=UDim2.new(1,-132,0,34),Size=UDim2.fromOffset(118,44),BackgroundColor3=here and C.light or C.lime,TextColor3=here and C.muted or C.bg,TextSize=13})
	end
end

local function helpPage()
	title.Text="A little guide"
	subtitle.Text="Find something weird. Feed it. Watch your garden grow."
	button(body,"Take me to the sand pit",function()
		local result=perform("Teleport",{destination="Meadow"})
		if result and result.ok then openPage(nil) end
	end,{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.lime,TextColor3=C.bg})
	for _,entry in ipairs({
		{"Find & collect","Stand on the sand and choose Dig (E). A scan takes one second, with a 50% chance to find a signal. Tap or press Space to capture it."},
		{"Feed & grow","Open Collection, choose a brainrot, and feed it from your pantry. Every creature earns coins while you play."},
		{"Rare finishes","Every found signal rolls a finish independently of species rarity: Bronze 12% (1.5x), Silver 5% (2x), Gold 2.5% (3x), Diamond 0.5% (5x). Others are Normal. Finishes improve income and sale value."},
		{"Upgrade your kit","Food, Sell, and Gear take you straight to their shops. Stronger detectors uncover higher rarities; boosts last five minutes."},
		{"Explore further","Use the glowing portal near each world’s entrance to travel or unlock new worlds. Hold Shift, click the left stick, or use Sprint on touch to move faster."},
		{"Make it yours","Use Index (I) to track all "..#Config.Creatures.." species. Garden (G) opens your six displays and teleports you home. Display choices and discoveries save with your collection."},
	}) do
		local f=card(body,entry[1]=="Rare finishes" and (body.AbsoluteSize.X<440 and 178 or 142) or 112)
		label(f,entry[1],16,C.text,{Position=UDim2.fromOffset(16,10),Size=UDim2.new(1,-32,0,24),Font=Enum.Font.BuilderSansMedium})
		label(f,entry[2],14,C.muted,{Position=UDim2.fromOffset(16,39),Size=UDim2.new(1,-32,1,-47),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	end
end

renderPage = function()
	renderedSignature = pageSignature()
	local scrollPosition = body.CanvasPosition
	for _, child in ipairs(body:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	viewports = {}
	if not state then empty("Connecting to your expedition..."); return end
	if activePage == "Collection" or activePage == "Sell" then collectionPage(activePage == "Sell")
	elseif activePage == "Detail" or activePage == "SellDetail" or activePage == "SellConfirm" then detailPage(activePage ~= "Detail")
	elseif activePage == "Food" then foodPage()
	elseif activePage == "Gear" then gearPage()
	elseif activePage == "Worlds" then worldsPage()
	elseif activePage == "Index" then indexPage()
	elseif activePage == "Garden" then gardenPage()
	else helpPage() end
	body.CanvasPosition = scrollPosition
end
openPage = function(page)
	if capture then return end
	local previousPage = activePage
	activePage = page
	screen:SetAttribute("MenuOpen", page ~= nil)
	shade.Visible = page ~= nil
	journalShortcuts.Visible = page == nil
	syncDetectorUI()
	if resize then resize(true) end
	for key, b in pairs(navButtons) do
		local on = key == page or (key == "Collection" and page == "Detail") or (key == "Sell" and (page == "SellDetail" or page == "SellConfirm"))
		b.BackgroundColor3 = on and C.bg or C.panel
		b.TextColor3 = on and C.paper or C.muted
		navLabels[key].TextColor3 = on and C.paper or C.muted
		for _,piece in ipairs(navIcons[key]:GetDescendants()) do
			if piece:GetAttribute("TintIcon") then piece.BackgroundColor3=on and C.paper or C.muted end
		end
	end
	if page then
		body.CanvasPosition=Vector2.zero; renderPage()
		if previousPage~=page then
			panel.Position=panelRestPosition+UDim2.fromOffset(0,8)
			TweenService:Create(panel,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=panelRestPosition}):Play()
		end
	end
end

-- The minigame reports taps to the server; the progress shown here never awards a creature.
local captureShade = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.22,
	Visible = false, BorderSizePixel = 0, Active = true, ZIndex = 30}, screen)
local capturePanel = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 410), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 31}, captureShade)
make("UISizeConstraint", {MaxSize = Vector2.new(440, 410)}, capturePanel)
corner(capturePanel, 22)
stroke(capturePanel, C.lime, 0.2)
label(capturePanel, "You found a signal", 12, C.green, {Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 22), TextXAlignment = Enum.TextXAlignment.Center})
local captureName = label(capturePanel, "A brainrot!", 26, C.text, {Position = UDim2.new(0, 20, 0, 43), Size = UDim2.new(1, -40, 0, 32), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.BuilderSansBold, TextScaled = true})
make("UITextSizeConstraint", {MaxTextSize = 26, MinTextSize = 15}, captureName)
local captureRarity = label(capturePanel, "COMMON", 13, C.muted, {AnchorPoint=Vector2.new(0.5,0),Position = UDim2.new(0.5, 0, 0, 79), Size = UDim2.new(1,-40,0,24),BackgroundColor3=C.light,TextXAlignment = Enum.TextXAlignment.Center,Font=Enum.Font.BuilderSansMedium})
corner(captureRarity,12)
captureRarity.TextScaled=true
make("UITextSizeConstraint",{MinTextSize=12,MaxTextSize=13},captureRarity)
local timerLabel = label(capturePanel, "0:10", 24, C.gold, {Name="CaptureTimer",AnchorPoint=Vector2.new(0.5,0),Position = UDim2.new(0.5, 0, 0, 232), Size = UDim2.fromOffset(112,36),BackgroundColor3=C.light,TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.BuilderSansBold})
corner(timerLabel,14)
local progressTrack = make("Frame", {Name="CaptureProgressTrack",Position = UDim2.new(0, 28, 0, 278), Size = UDim2.new(1, -56, 0, 10), BackgroundColor3 = C.line, BorderSizePixel = 0}, capturePanel)
corner(progressTrack, 6)
local progressFill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.lime, BorderSizePixel = 0}, progressTrack)
corner(progressFill, 6)
local captureProgress = label(capturePanel, "0 / 0 taps", 14, C.text, {Position = UDim2.new(0, 20, 0, 292), Size = UDim2.new(1, -40, 0, 22), TextXAlignment = Enum.TextXAlignment.Center})
local tapButton = button(capturePanel, "Tap to collect", function() tapDig() end,
	{Position = UDim2.new(0, 24, 0, 326), Size = UDim2.new(1, -48, 0, 48), BackgroundColor3 = C.lime, TextColor3 = C.bg, TextSize = 17})
label(capturePanel, "Tap the button or press Space", 12, C.muted, {Position = UDim2.new(0, 20, 0, 380), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Center})

local capturePreview=make("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,104),Size=UDim2.fromOffset(180,126)},capturePanel)

local function endCapture(message, kind)
	capture = nil
	screen:SetAttribute("Capturing", false)
	captureShade.Visible = false
	for _,child in capturePreview:GetChildren() do child:Destroy() end
	ContextActionService:UnbindAction("BrainrotCaptureTap")
	syncDetectorUI()
	if message then notify(message, kind) end
end
local function celebrate(color)
	for index = 1, 20 do
		local particle = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.new(0, index % 2 == 0 and 7 or 5, 0, 10), BackgroundColor3 = index % 3 == 0 and C.gold or color,
			BorderSizePixel = 0, Rotation = index * 18, ZIndex = 40}, screen)
		corner(particle, 2)
		TweenService:Create(particle, TweenInfo.new(0.8 + index * 0.02, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Position = UDim2.fromScale(0.12 + (index % 10) * 0.084, 0.55 + (index % 5) * 0.07),
				Rotation = index * 59, BackgroundTransparency = 1}):Play()
		task.delay(1.3, function() particle:Destroy() end)
	end
end
tapDig = function()
	if not capture or capturePending or capture.deadline <= os.clock() then return end
	if os.clock() - (capture.lastTap or 0) < 0.06 then return end
	capture.lastTap = os.clock()
	capturePending = true
	local session = capture
	local result = request("TapDig", {sessionId = session.id})
	capturePending = false
	if capture ~= session then return end
	if not result or not result.ok then
		endCapture(result and result.message or "Capture interrupted. Try another signal.", "error")
		return
	end
	session.taps = result.taps or result.count or (session.taps + 1)
	captureProgress.Text = session.taps .. " / " .. session.required .. " taps"
	TweenService:Create(progressFill, TweenInfo.new(0.08), {Size = UDim2.fromScale(math.clamp(session.taps / session.required, 0, 1), 1)}):Play()
	if result.complete then
		endCapture(result.message or ("Captured " .. brainrotName(session) .. "! Open your collection to feed it."), "success")
		celebrate(variantTint(session.variant,session.rarity))
	end
end
startDig = function()
	if busy or capture or activePage or not detectorEquipped() then return end
	busy = true
	screen:SetAttribute("Scanning", true)
	digButton.Text = "Scanning…"
	digButton.BackgroundColor3 = C.honey
	digButton.TextColor3=C.bg
	-- The server waits for the scan and rolls the find chance; this UI stays busy until it resolves.
	local result = request("StartDig")
	busy = false
	screen:SetAttribute("Scanning", false)
	digButton.Text = UserInputService.TouchEnabled and "Dig" or "Dig  ·  E"
	digButton.BackgroundColor3 = C.bg
	digButton.TextColor3=C.paper
	if not result or not result.ok or not result.dig then return end
	local dig = result.dig
	capture = {id = dig.id, required = dig.required, duration = dig.duration, deadline = os.clock() + dig.duration, taps = 0, name = dig.name or "brainrot", rarity = dig.rarity,variant=Config.variant(dig.variant).id}
	syncDetectorUI()
	screen:SetAttribute("Capturing", true)
	captureName.Text = brainrotName(capture)
	local r = rarity(dig.rarity)
	local tint=variantTint(dig.variant,dig.rarity)
	captureRarity.Text = r.name.." · "..variantCaption(dig.variant)
	captureRarity.TextColor3 = readable(tint)
	captureRarity.BackgroundColor3 = tint:Lerp(C.paper,0.84)
	progressFill.BackgroundColor3 = readable(tint)
	progressFill.Size = UDim2.fromScale(0, 1)
	captureProgress.Text = "0 / " .. capture.required .. " taps"
	for _,child in capturePreview:GetChildren() do child:Destroy() end
	previewStage(capturePreview,tint,UDim2.new(),UDim2.fromScale(1,1))
	viewport(capturePreview,dig.specId,UDim2.fromScale(1,1),nil,{variant=dig.variant})
	captureShade.Visible = true
	capturePanel.Position=UDim2.new(0.5,0,0.5,6)
	TweenService:Create(capturePanel,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromScale(0.5,0.5)}):Play()
	ContextActionService:BindActionAtPriority("BrainrotCaptureTap", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then task.spawn(tapDig) end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Space)
end

State.OnClientEvent:Connect(function(newState)
	if type(newState) ~= "table" then return end
	state = newState
	updateHud()
	-- Do not destroy an active button during a purchase response.
	if activePage and not busy and pageSignature() ~= renderedSignature then renderPage() end
end)
Notify.OnClientEvent:Connect(function(message, kind)
	if type(kind) == "string" and string.sub(kind, 1, 5) == "shop:" then
		openPage(string.sub(kind, 6))
		return
	end
	notify(message, kind)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.E then task.spawn(startDig)
	elseif input.KeyCode == Enum.KeyCode.I and not capture then openPage("Index")
	elseif input.KeyCode == Enum.KeyCode.G and not capture then openPage("Garden")
	elseif input.KeyCode == Enum.KeyCode.B and not capture then
		if activePage then openPage(nil) else openPage("Collection") end
	elseif input.KeyCode == Enum.KeyCode.Escape and activePage then openPage(nil) end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer and triggeringPlayer ~= player then return end
	if prompt:GetAttribute("Garden") or prompt:GetAttribute("GardenSlot") then
		if state and state.garden and prompt:GetAttribute("GardenId")==state.garden.id then
			local slot=prompt:GetAttribute("GardenSlot")
			if type(slot)=="number" then selectedGardenSlot=math.clamp(slot,1,state.garden.capacity or 6) end
			selectedGardenUid=nil
			openPage("Garden")
		else notify("This is another player's garden. Open Garden to arrange your own displays.") end
		return
	end
	local shop = prompt:GetAttribute("Shop")
	if shop == "Food" or shop == "Sell" or shop == "Gear" then openPage(shop) end
	if prompt:GetAttribute("WorldTravel") then openPage("Worlds") end
end)

local animationTime = 0
local countdownAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
	animationTime += dt
	countdownAccumulator += dt
	if activePage then
		for _, entry in ipairs(viewports) do
			if entry.model.Parent then entry.model:PivotTo(entry.base * CFrame.Angles(0, math.sin(animationTime * 0.55) * 0.3, 0)) end
		end
	end
	if capture then
		local remaining = capture.deadline - os.clock()
		timerLabel.Text = string.format("%.1fs", math.max(0, remaining))
		timerLabel.TextColor3 = remaining < 3 and C.red or C.gold
		if remaining <= 0 then endCapture("The signal faded! Tap faster on your next find.", "error") end
	end
	if countdownAccumulator >= 0.25 then
		countdownAccumulator = 0
		local countdown = body:FindFirstChild("RotationCountdown")
		if countdown and state then countdown.Text = "Restocks in " .. seconds((state.rotationEnds or now()) - now()) end
		if activePage then
			for _, item in ipairs(body:GetDescendants()) do
				if item:IsA("TextLabel") then
					local boostUntil = item:GetAttribute("BoostUntil")
					local growthUntil = item:GetAttribute("GrowthUntil")
					if boostUntil then
						local remaining = boostUntil - now()
						item.Text = remaining > 0 and ("Active  " .. seconds(remaining)) or "Boost expired"
						item.TextColor3 = remaining > 0 and C.green or C.muted
					elseif growthUntil then
						local growth = growthUntil - now()
						local income = (item:GetAttribute("IncomeUntil") or 0) - now()
						item.Text = (growth > 0 and "2x growth: " .. seconds(growth) .. "   " or "") .. (income > 0 and "2x income: " .. seconds(income) or "")
						if growth <= 0 and income <= 0 then item.Text = "Boosts expired" end
					end
				end
			end
		end
	end
end)

resize = function(skipPageRender)
	local size = screen.AbsoluteSize
	if size.X<1 or size.Y<1 then return end
	local compactDock=size.Y<600 and size.X>=520
	local dockWidth=compactDock and 218 or (size.X<600 and 112 or 132)
	local dockHeight=compactDock and 156 or 306
	local dockCenter=compactDock and math.min(size.Y/2,size.Y-120-dockHeight/2) or size.Y/2
	nav.Size=UDim2.fromOffset(dockWidth,dockHeight)
	nav.Position=UDim2.fromOffset(12,dockCenter)
	nav:SetAttribute("LayoutColumns",compactDock and 2 or 1)
	local walletLeft=compactDock and dockWidth+24 or 12
	local walletWidth=math.min(304,math.max(180,size.X-walletLeft-70))
	hud.Position=UDim2.fromOffset(walletLeft,12)
	hud.Size = UDim2.fromOffset(walletWidth,96)
	coinsLabel.TextSize=walletWidth<230 and 20 or 27
	helpButton.Position = UDim2.new(1, -12, 0, 12)
	hud.Visible=activePage==nil
	helpButton.Visible=activePage==nil
	for index,name in ipairs({"Collection","Food","Sell","Gear"}) do
		local column=compactDock and (index-1)%2 or 0
		local rowIndex=compactDock and math.floor((index-1)/2) or index-1
		navButtons[name].Position=UDim2.fromOffset(6+column*106,6+rowIndex*50)
		navButtons[name].Size=UDim2.fromOffset(compactDock and 100 or dockWidth-12,44)
		navLabels[name].Text=name=="Collection" and (size.X<900 and "Bag" or "Collection") or name
	end
	journalShortcuts.Position=UDim2.fromOffset(6,compactDock and 106 or 206)
	journalShortcuts.Size=UDim2.fromOffset(dockWidth-12,compactDock and 44 or 94)
	for index,name in ipairs({"Index","Garden"}) do
		journalButtons[name].Position=UDim2.fromOffset(compactDock and (index-1)*106 or 0,compactDock and 0 or (index-1)*50)
		journalButtons[name].Size=UDim2.fromOffset(compactDock and 100 or dockWidth-12,44)
	end
	-- The modal shade sits above the dock, so pages can use the full screen
	-- without leaving navigation buttons over their headings or close control.
	local panelHeight=math.min(660,math.max(180,size.Y-24))
	panel.Size=UDim2.new(0.94,0,0,panelHeight)
	panelRestPosition=UDim2.fromOffset(size.X/2,size.Y/2)
	panel.Position=panelRestPosition
	if compactDock then
		local toastWidth=math.min(540,size.X-dockWidth-36)
		toast.Size=UDim2.fromOffset(toastWidth,52)
		toast.Position=UDim2.fromOffset(walletLeft+toastWidth/2,118)
	else
		toast.Size=UDim2.new(0.88,0,0,52)
		toast.Position=UDim2.new(0.5,0,0,118)
	end
	if not skipPageRender and activePage then renderPage() end
	capturePanel.Size = UDim2.new(0.9, 0, 0, math.min(410, size.Y - 24))
	if size.Y < 450 then
		capturePanel.Size = UDim2.new(0.9, 0, 0, 410)
		local scale = capturePanel:FindFirstChildOfClass("UIScale") or make("UIScale", {}, capturePanel)
		scale.Scale = (size.Y - 24) / 410
	else
		local scale = capturePanel:FindFirstChildOfClass("UIScale")
		if scale then scale.Scale = 1 end
	end
end
screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
resize()
if UserInputService.TouchEnabled then digButton.Text = "Dig" end

task.spawn(function()
	-- Profile loading may outlast replication of the remotes, especially when
	-- Studio is waiting for DataStore retries. State events can resolve it too.
	for attempt = 1, 30 do
		if state then break end
		local ok, result = pcall(function() return Action:InvokeServer("GetState", {}) end)
		if ok and type(result) == "table" and result.ok and result.state then
			state = result.state
			break
		end
		task.wait(1)
	end
	if state then
		updateHud()
		if #(state.brainrots or {}) == 0 and not activePage and not capture then openPage("Help") end
	else
		notify("Could not load your collection. Rejoin if the connection does not recover.", "error")
	end
end)
